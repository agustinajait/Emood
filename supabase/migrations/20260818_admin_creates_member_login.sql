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
