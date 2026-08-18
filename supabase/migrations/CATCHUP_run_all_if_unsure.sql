-- ============================================================
-- E-Mood — Migración a multi-organización (multi-tenant)
-- ============================================================
-- Qué hace:
--   1) Crea la tabla `organizations` (las empresas cliente).
--   2) Crea la tabla `profiles` (usuarios reales, ligados a auth.users,
--      con rol y organización).
--   3) Agrega `organization_id` a todas las tablas hh_* existentes.
--   4) Mete todos los datos actuales dentro de una organización
--      "Organización original" (para no perder nada de lo ya cargado).
--   5) Activa Row Level Security: cada organización solo ve sus propios
--      datos, nunca los de otra.
--   6) Crea la función `create_organization_and_admin(...)` que usa el
--      flujo de autoregistro: primero se crea el usuario con
--      supabase.auth.signUp(), y después se llama a esta función para
--      crear su organización y quedar como admin de la misma.
--
-- Se puede ejecutar más de una vez sin romper nada (usa IF NOT EXISTS /
-- DROP POLICY IF EXISTS en todos lados).
-- ============================================================

begin;

create extension if not exists pgcrypto;

-- ── 1) Organizaciones ──────────────────────────────────────
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  plan text not null default 'trial',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ── 2) Perfiles (usuarios reales) ──────────────────────────
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  role text not null default 'admin' check (role in ('admin','socio','prestador')),
  full_name text default '',
  email text,
  prestador_id text,  -- referencia libre al id de hh_prestadores (login de prestador)
  agency_id text,     -- referencia libre al id de hh_agencies (login de socio responsable)
  created_at timestamptz not null default now()
);

-- ── 3) organization_id en todas las tablas hh_* ────────────
do $$
declare
  t text;
  tables text[] := array[
    'hh_agencies','hh_challenges','hh_checkins','hh_products',
    'hh_certifications','hh_comments','hh_prestadores','hh_protocolos',
    'hh_items_globales','hh_seguimientos','hh_modulos','hh_modulo_evidencias',
    'hh_ecosistemas'
  ];
begin
  foreach t in array tables loop
    if to_regclass('public.'||t) is not null then
      execute format(
        'alter table public.%I add column if not exists organization_id uuid references public.organizations(id)',
        t
      );
    end if;
  end loop;
end $$;

-- ── 4) Backfill: organización "legacy" para los datos actuales ─
do $$
declare
  legacy_org_id uuid;
  t text;
  tables text[] := array[
    'hh_agencies','hh_challenges','hh_checkins','hh_products',
    'hh_certifications','hh_comments','hh_prestadores','hh_protocolos',
    'hh_items_globales','hh_seguimientos','hh_modulos','hh_modulo_evidencias',
    'hh_ecosistemas'
  ];
begin
  select id into legacy_org_id from public.organizations where slug = 'organizacion-original' limit 1;
  if legacy_org_id is null then
    insert into public.organizations (name, slug, plan, active)
    values ('Organización original', 'organizacion-original', 'legacy', true)
    returning id into legacy_org_id;
  end if;

  foreach t in array tables loop
    if to_regclass('public.'||t) is not null then
      execute format('update public.%I set organization_id = %L where organization_id is null', t, legacy_org_id);
      execute format('alter table public.%I alter column organization_id set not null', t);
    end if;
  end loop;
end $$;

-- ── 5) Función helper: organización del usuario logueado ───
-- SECURITY DEFINER a propósito: evita recursión de RLS al leer profiles
-- desde adentro de las políticas de las tablas hh_*.
create or replace function public.current_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select organization_id from public.profiles where id = auth.uid();
$$;

-- ── 6) Row Level Security ──────────────────────────────────
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;

do $$
declare
  t text;
  tables text[] := array[
    'hh_agencies','hh_challenges','hh_checkins','hh_products',
    'hh_certifications','hh_comments','hh_prestadores','hh_protocolos',
    'hh_items_globales','hh_seguimientos','hh_modulos','hh_modulo_evidencias',
    'hh_ecosistemas'
  ];
begin
  foreach t in array tables loop
    if to_regclass('public.'||t) is not null then
      execute format('alter table public.%I enable row level security', t);

      execute format('drop policy if exists %I_select on public.%I', t, t);
      execute format(
        'create policy %I_select on public.%I for select using (organization_id = public.current_org_id())',
        t, t
      );

      execute format('drop policy if exists %I_insert on public.%I', t, t);
      execute format(
        'create policy %I_insert on public.%I for insert with check (organization_id = public.current_org_id())',
        t, t
      );

      execute format('drop policy if exists %I_update on public.%I', t, t);
      execute format(
        'create policy %I_update on public.%I for update using (organization_id = public.current_org_id()) with check (organization_id = public.current_org_id())',
        t, t
      );

      execute format('drop policy if exists %I_delete on public.%I', t, t);
      execute format(
        'create policy %I_delete on public.%I for delete using (organization_id = public.current_org_id())',
        t, t
      );
    end if;
  end loop;
end $$;

-- Organizations: cada usuario ve y edita solo la suya
drop policy if exists org_select on public.organizations;
create policy org_select on public.organizations for select
  using (id = public.current_org_id());

drop policy if exists org_update on public.organizations;
create policy org_update on public.organizations for update
  using (id = public.current_org_id())
  with check (id = public.current_org_id());

-- Profiles: cada usuario ve su propio perfil y los de su organización
-- (para que el admin pueda ver la lista de gente de su empresa).
-- A propósito NO hay política de INSERT directo: el alta de perfiles
-- solo puede pasar a través de las funciones SECURITY DEFINER de abajo,
-- para que nadie pueda auto-asignarse a la organización de otro.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or organization_id = public.current_org_id());

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- ── 7) Alta de organización nueva (autoregistro) ───────────
-- Flujo desde la app:
--   1. supabase.auth.signUp({ email, password })
--   2. supabase.rpc('create_organization_and_admin', { org_name, admin_name })
create or replace function public.create_organization_and_admin(
  org_name text,
  admin_name text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_org_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Necesitás una sesión iniciada para crear una organización';
  end if;

  if exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'Este usuario ya pertenece a una organización';
  end if;

  if coalesce(trim(org_name), '') = '' then
    raise exception 'El nombre de la organización es obligatorio';
  end if;

  insert into public.organizations (name, plan, active)
  values (trim(org_name), 'trial', true)
  returning id into new_org_id;

  insert into public.profiles (id, organization_id, role, full_name, email)
  values (auth.uid(), new_org_id, 'admin', trim(admin_name), auth.email());

  return new_org_id;
end;
$$;

grant execute on function public.create_organization_and_admin(text, text) to authenticated;
grant execute on function public.current_org_id() to authenticated;

commit;

-- ── Verificación rápida (opcional, solo lectura) ───────────
select o.name, o.slug, o.plan,
       (select count(*) from public.hh_agencies a where a.organization_id = o.id) as agencias,
       (select count(*) from public.hh_prestadores p where p.organization_id = o.id) as prestadores
from public.organizations o
order by o.created_at;
-- ============================================================
-- E-Mood — El admin de una organización puede dar de alta el
-- login de un prestador (o socio) de su propia organización.
-- ============================================================
-- Flujo desde la app (botón "🔑 Dar acceso" en el detalle de un
-- prestador):
--   1. El admin, YA logueado, crea la cuenta de Auth de la otra
--      persona con POST /auth/v1/signup (email + contraseña) —
--      esto no toca la sesión del admin, solo crea el auth.users.
--   2. El admin llama a este RPC pasándole el id de ese usuario
--      nuevo, para crear su fila en profiles ligada a la MISMA
--      organización del admin.
-- ============================================================

create or replace function public.admin_create_member_profile(
  new_user_id uuid,
  member_role text,
  full_name text default '',
  prestador_id text default null,
  agency_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_org_id uuid;
  admin_role text;
begin
  if auth.uid() is null then
    raise exception 'Necesitás una sesión iniciada';
  end if;

  select organization_id, role into admin_org_id, admin_role
  from public.profiles where id = auth.uid();

  if admin_org_id is null or admin_role <> 'admin' then
    raise exception 'Solo un administrador puede crear accesos para su organización';
  end if;

  if member_role not in ('prestador','socio') then
    raise exception 'Rol inválido: %', member_role;
  end if;

  if new_user_id is null then
    raise exception 'Falta el id del usuario a vincular';
  end if;

  if exists (select 1 from public.profiles where id = new_user_id) then
    raise exception 'Esa cuenta ya tiene un perfil asignado';
  end if;

  insert into public.profiles (id, organization_id, role, full_name, prestador_id, agency_id)
  values (new_user_id, admin_org_id, member_role, coalesce(full_name,''), prestador_id, agency_id);
end;
$$;

grant execute on function public.admin_create_member_profile(uuid, text, text, text, text) to authenticated;
-- ============================================================
-- E-Mood — Flujo Servicio → Postulación → Módulo asignado → Remito
-- ============================================================
-- ORG crea Servicio
--   → prestador carga sus datos y aplica (Postulación)
--   → org acepta → se crea Módulo asignado (copia el protocolo del Servicio)
--   → prestador sube evidencia por cada ítem del protocolo
--   → org aprueba/rechaza cada ítem
--   → cuando todos los ítems están aprobados → módulo = 'completado'
--   → org genera Remito → módulo = 'aprobado'
-- ============================================================

begin;

-- ── Servicios (lo que la organización publica) ─────────────
create table if not exists public.hh_servicios (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  titulo text not null,
  descripcion text default '',
  frecuencia text not null default 'mensual' check (frecuencia in ('diaria','semanal','mensual','unica')),
  horas_modulo numeric not null default 0,
  precio_hora numeric not null default 0,
  deadline date,
  protocolo text not null default '[]',       -- JSON.stringify [{item, descripcion}]
  docs_requeridos text not null default '[]',  -- JSON.stringify ["DNI","CUIL",...]
  estado text not null default 'activo' check (estado in ('activo','cerrado')),
  created_at timestamptz not null default now()
);

-- ── Postulaciones (prestador aplica a un Servicio) ──────────
create table if not exists public.hh_postulaciones (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  servicio_id text not null references public.hh_servicios(id) on delete cascade,
  prestador_id text not null references public.hh_prestadores(id) on delete cascade,
  mensaje text default '',
  docs_confirmados text not null default '[]', -- JSON.stringify de los docs que el prestador marcó como presentados
  estado text not null default 'pendiente' check (estado in ('pendiente','aceptada','rechazada')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (servicio_id, prestador_id)
);

-- ── Módulos asignados (instancia real de trabajo, nace al aceptar
--    una postulación; el protocolo se copia tal cual estaba en el
--    Servicio en ese momento) ─────────────────────────────────
create table if not exists public.hh_modulos_asignados (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  servicio_id text not null references public.hh_servicios(id) on delete cascade,
  postulacion_id text references public.hh_postulaciones(id) on delete set null,
  prestador_id text not null references public.hh_prestadores(id) on delete cascade,
  protocolo text not null default '[]', -- snapshot JSON del protocolo al momento de asignar
  estado text not null default 'en_progreso' check (estado in ('en_progreso','completado','aprobado')),
  remito_numero text,
  remito_fecha timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── Ítems del módulo asignado (uno por ítem del protocolo;
--    evidencia y aprobación van por ítem) ───────────────────
create table if not exists public.hh_modulo_items (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  modulo_asignado_id text not null references public.hh_modulos_asignados(id) on delete cascade,
  item text not null,
  descripcion text default '',
  evidencia_url text default '',
  evidencia_nota text default '',
  estado text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  comentario_org text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── RLS: mismo patrón que el resto (acotado a organization_id) ─
do $$
declare
  t text;
  tables text[] := array['hh_servicios','hh_postulaciones','hh_modulos_asignados','hh_modulo_items'];
begin
  foreach t in array tables loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I_select on public.%I', t, t);
    execute format('create policy %I_select on public.%I for select using (organization_id = public.current_org_id())', t, t);

    execute format('drop policy if exists %I_insert on public.%I', t, t);
    execute format('create policy %I_insert on public.%I for insert with check (organization_id = public.current_org_id())', t, t);

    execute format('drop policy if exists %I_update on public.%I', t, t);
    execute format('create policy %I_update on public.%I for update using (organization_id = public.current_org_id()) with check (organization_id = public.current_org_id())', t, t);

    execute format('drop policy if exists %I_delete on public.%I', t, t);
    execute format('create policy %I_delete on public.%I for delete using (organization_id = public.current_org_id())', t, t);
  end loop;
end $$;

commit;
-- ============================================================
-- E-Mood — Un prestador pertenece a un ecosistema (proyecto).
-- Una organización puede tener varios ecosistemas, cada uno con
-- sus propios prestadores.
-- ============================================================

alter table if exists public.hh_prestadores
  add column if not exists ecosistema_id text;
-- ============================================================
-- E-Mood — Prestadores como pool compartido de la plataforma
-- ============================================================
-- Cambio de fondo: un prestador se da de alta UNA vez en E-Mood
-- (no dentro de una organización) y puede postularse y trabajar
-- para VARIAS organizaciones a la vez. La relación con cada
-- organización vive en la Postulación / Módulo asignado — el
-- prestador en sí ya no tiene organization_id fijo.
--
-- También agrega a Servicios: cupos, cantidad por período (para
-- que un módulo diario sume a un total mensual), y fechas de
-- inicio/fin (duración), además de a qué ecosistema de la
-- organización pertenece.
-- ============================================================

begin;

-- ── 1) profiles.organization_id pasa a ser opcional ─────────
-- (un admin/staff SIGUE necesitando organización; un prestador no)
alter table public.profiles alter column organization_id drop not null;
alter table public.profiles drop constraint if exists profiles_organization_id_fkey;
alter table public.profiles
  add constraint profiles_organization_id_fkey
  foreign key (organization_id) references public.organizations(id) on delete cascade;

-- ── 2) hh_prestadores deja de pertenecer a una organización ─
alter table public.hh_prestadores alter column organization_id drop not null;

-- Sacamos las políticas genéricas que asumían "una org, un dueño"
drop policy if exists hh_prestadores_select on public.hh_prestadores;
drop policy if exists hh_prestadores_insert on public.hh_prestadores;
drop policy if exists hh_prestadores_update on public.hh_prestadores;
drop policy if exists hh_prestadores_delete on public.hh_prestadores;

-- Helper: el prestador_id del usuario logueado (si es un prestador)
create or replace function public.my_prestador_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select prestador_id from public.profiles where id = auth.uid();
$$;

-- Un prestador ve/edita su propio legajo. Una organización ve el
-- legajo de los prestadores que se postularon o tienen módulos
-- con ella (no ve a los demás).
create policy hh_prestadores_select on public.hh_prestadores for select using (
  id = public.my_prestador_id()
  or exists (select 1 from public.hh_postulaciones po where po.prestador_id = hh_prestadores.id and po.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_modulos_asignados ma where ma.prestador_id = hh_prestadores.id and ma.organization_id = public.current_org_id())
);
create policy hh_prestadores_insert on public.hh_prestadores for insert with check (true);
create policy hh_prestadores_update on public.hh_prestadores for update using (
  id = public.my_prestador_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.prestador_id = hh_prestadores.id and ma.organization_id = public.current_org_id())
);
create policy hh_prestadores_delete on public.hh_prestadores for delete using (
  id = public.my_prestador_id()
);

-- ── 3) Alta de prestador (autoregistro, sin admin de por medio) ─
create or replace function public.create_prestador_account(
  nombre text,
  contacto text default '',
  drive_link text default ''
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_prestador_id text;
begin
  if auth.uid() is null then
    raise exception 'Necesitás una sesión iniciada';
  end if;
  if exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'Este usuario ya tiene un perfil asignado';
  end if;
  if coalesce(trim(nombre), '') = '' then
    raise exception 'El nombre es obligatorio';
  end if;

  new_prestador_id := replace(gen_random_uuid()::text, '-', '');

  insert into public.hh_prestadores (id, nombre, contacto, drive_link, activo, created_at)
  values (new_prestador_id, trim(nombre), coalesce(contacto,''), coalesce(drive_link,''), true, now());

  insert into public.profiles (id, organization_id, role, full_name, email, prestador_id)
  values (auth.uid(), null, 'prestador', trim(nombre), auth.email(), new_prestador_id);

  return new_prestador_id;
end;
$$;
grant execute on function public.create_prestador_account(text, text, text) to authenticated;
grant execute on function public.my_prestador_id() to authenticated;

-- ── 4) Servicios: cupos, cantidad por período, duración, ecosistema ─
alter table public.hh_servicios add column if not exists cupos integer not null default 1;
alter table public.hh_servicios add column if not exists cantidad_por_periodo numeric not null default 1; -- ej: diario x 22 veces al mes
alter table public.hh_servicios add column if not exists fecha_inicio date;
alter table public.hh_servicios add column if not exists fecha_fin date;
alter table public.hh_servicios add column if not exists ecosistema_id text;

-- ── 5) Servicios y Postulaciones/Módulos: acceso también para
--       prestadores (no solo la org dueña) ──────────────────
drop policy if exists hh_servicios_select on public.hh_servicios;
create policy hh_servicios_select on public.hh_servicios for select using (
  organization_id = public.current_org_id()
  or (estado = 'activo' and public.my_prestador_id() is not null)
);

drop policy if exists hh_postulaciones_select on public.hh_postulaciones;
create policy hh_postulaciones_select on public.hh_postulaciones for select using (
  organization_id = public.current_org_id()
  or prestador_id = public.my_prestador_id()
);
drop policy if exists hh_postulaciones_insert on public.hh_postulaciones;
create policy hh_postulaciones_insert on public.hh_postulaciones for insert with check (
  prestador_id = public.my_prestador_id()
);
drop policy if exists hh_postulaciones_update on public.hh_postulaciones;
create policy hh_postulaciones_update on public.hh_postulaciones for update using (
  organization_id = public.current_org_id()
  or prestador_id = public.my_prestador_id()
);

drop policy if exists hh_modulos_asignados_select on public.hh_modulos_asignados;
create policy hh_modulos_asignados_select on public.hh_modulos_asignados for select using (
  organization_id = public.current_org_id()
  or prestador_id = public.my_prestador_id()
);
drop policy if exists hh_modulo_items_select on public.hh_modulo_items;
create policy hh_modulo_items_select on public.hh_modulo_items for select using (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_items.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);
drop policy if exists hh_modulo_items_update on public.hh_modulo_items;
create policy hh_modulo_items_update on public.hh_modulo_items for update using (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_items.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

commit;
-- ============================================================
-- E-Mood — Ciclos mensuales por módulo asignado
-- ============================================================
-- Un módulo asignado (ej: 3 meses de trabajo) ahora se factura por
-- CICLO (mes): cada ciclo tiene su propia copia de los ítems del
-- protocolo, su propia evidencia/aprobación, y su propio remito.
-- Antes el remito era uno solo por todo el módulo asignado; ahora
-- es uno por mes.
-- ============================================================

begin;

create table if not exists public.hh_modulo_ciclos (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  modulo_asignado_id text not null references public.hh_modulos_asignados(id) on delete cascade,
  periodo text not null, -- 'YYYY-MM'
  estado text not null default 'en_progreso' check (estado in ('en_progreso','completado','aprobado')),
  remito_numero text,
  remito_fecha timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (modulo_asignado_id, periodo)
);

-- Los ítems de evidencia ahora cuelgan de un ciclo (mes), no
-- directamente del módulo asignado. Mantenemos modulo_asignado_id
-- también (no rompe las políticas RLS que ya existían sobre esta
-- tabla, y sirve para consultas directas).
alter table public.hh_modulo_items add column if not exists ciclo_id text references public.hh_modulo_ciclos(id) on delete cascade;

alter table public.hh_modulo_ciclos enable row level security;

drop policy if exists hh_modulo_ciclos_select on public.hh_modulo_ciclos;
create policy hh_modulo_ciclos_select on public.hh_modulo_ciclos for select using (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_ciclos.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);
drop policy if exists hh_modulo_ciclos_insert on public.hh_modulo_ciclos;
create policy hh_modulo_ciclos_insert on public.hh_modulo_ciclos for insert with check (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_ciclos.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);
drop policy if exists hh_modulo_ciclos_update on public.hh_modulo_ciclos;
create policy hh_modulo_ciclos_update on public.hh_modulo_ciclos for update using (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_ciclos.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

commit;
-- ============================================================
-- E-Mood — Tipo de contrato del módulo (Servicio) + documento
-- ============================================================
-- Va en la descripción del módulo, no en el prestador: la
-- organización indica bajo qué figura se contrata ese servicio
-- (Monotributo, etc.) y puede adjuntar un documento de referencia.
-- ============================================================

alter table if exists public.hh_servicios
  add column if not exists tipo_contrato text,
  add column if not exists doc_adjunto_url text;

-- Bucket de storage para los documentos adjuntos al módulo
insert into storage.buckets (id, name, public)
values ('modulo-docs', 'modulo-docs', true)
on conflict (id) do nothing;

drop policy if exists "modulo-docs insert" on storage.objects;
create policy "modulo-docs insert" on storage.objects for insert to authenticated
with check (bucket_id = 'modulo-docs');

drop policy if exists "modulo-docs select" on storage.objects;
create policy "modulo-docs select" on storage.objects for select
using (bucket_id = 'modulo-docs');

drop policy if exists "modulo-docs update" on storage.objects;
create policy "modulo-docs update" on storage.objects for update to authenticated
using (bucket_id = 'modulo-docs');
-- ============================================================
-- E-Mood — Tipo de contrato del prestador + documento adjunto
-- ============================================================

alter table if exists public.hh_prestadores
  add column if not exists tipo_contrato text,
  add column if not exists doc_contrato_url text;

-- Bucket de storage para los documentos de contrato (monotributo, etc.)
insert into storage.buckets (id, name, public)
values ('prestador-docs', 'prestador-docs', true)
on conflict (id) do nothing;

drop policy if exists "prestador-docs insert" on storage.objects;
create policy "prestador-docs insert" on storage.objects for insert to authenticated
with check (bucket_id = 'prestador-docs');

drop policy if exists "prestador-docs select" on storage.objects;
create policy "prestador-docs select" on storage.objects for select
using (bucket_id = 'prestador-docs');

drop policy if exists "prestador-docs update" on storage.objects;
create policy "prestador-docs update" on storage.objects for update to authenticated
using (bucket_id = 'prestador-docs');
-- ============================================================
-- E-Mood — Arreglo: el prestador no podía crear los ítems del
-- ciclo cuando abre un mes nuevo desde su propio panel.
-- ============================================================
-- La política de INSERT de hh_modulo_items nunca se actualizó al
-- introducir los ciclos mensuales — seguía exigiendo que quien
-- inserta sea la organización dueña (organization_id = current_org_id()),
-- lo cual es imposible para un prestador (no tiene organización propia).
-- Como hh_modulo_ciclos_insert sí se corrigió, el ciclo se creaba
-- pero sus ítems no, dejando el ciclo vacío.
-- ============================================================

begin;

drop policy if exists hh_modulo_items_insert on public.hh_modulo_items;
create policy hh_modulo_items_insert on public.hh_modulo_items for insert with check (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_items.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

commit;
