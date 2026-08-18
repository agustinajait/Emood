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
