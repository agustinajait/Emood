-- ============================================================
-- E-Mood — "Dar acceso" (admin_create_member_profile) fallaba para
-- superadmin y coordinador
-- ============================================================
-- admin_create_member_profile() nunca se actualizó desde que se creó
-- (20260818_admin_creates_member_login.sql): exigía role = 'admin'
-- exacto. El botón "🔑 Dar acceso" hace 2 pasos — 1) crea la cuenta de
-- Auth (POST /auth/v1/signup), que SIEMPRE funciona, y 2) llama a
-- este RPC para vincularla al perfil, que fallaba en silencio para
-- cualquiera que no fuera literalmente "admin" (superadmin,
-- coordinador). Resultado: quedaba una cuenta de Auth creada pero
-- SIN perfil (huérfana) — y al reintentar, el paso 1 ahora falla
-- porque el email "ya está en uso", escondiendo el error real.
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

  if admin_org_id is null or admin_role not in ('admin','coordinador','superadmin') then
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
