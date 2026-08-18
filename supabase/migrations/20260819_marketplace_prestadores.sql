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
