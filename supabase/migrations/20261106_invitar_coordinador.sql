-- ============================================================
-- E-Mood — Rol "coordinador": un admin de organización puede sumar
-- colegas por su cuenta (sin pasar por el superadmin)
-- ============================================================
-- "Invitar administrador" sigue siendo exclusivo del superadmin
-- (20260908_invitar_admin_solo_superadmin.sql) — cada organización
-- sigue teniendo un admin "fijo" que decide el superadmin. Pero
-- ahora cualquier admin/coordinador YA existente de una organización
-- puede invitar "coordinadores" para SU PROPIA organización — mismo
-- nivel de acceso que un admin (todas las políticas RLS existentes
-- ya solo miran organization_id = current_org_id(), no el role), el
-- rol distinto es solo para que se sepa quién es quién en el equipo.
-- ============================================================

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('admin','socio','prestador','superadmin','coordinador'));

alter table public.org_admin_invites add column if not exists role text not null default 'admin';
alter table public.org_admin_invites drop constraint if exists org_admin_invites_role_check;
alter table public.org_admin_invites add constraint org_admin_invites_role_check check (role in ('admin','coordinador'));

create or replace function public.generar_invitacion_admin(target_org_id uuid, p_role text default 'admin')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token uuid;
begin
  if p_role not in ('admin', 'coordinador') then
    raise exception 'Rol inválido';
  end if;

  if p_role = 'coordinador' then
    if not (public.is_superadmin() or target_org_id = public.current_org_id()) then
      raise exception 'No tenés permiso para invitar coordinadores de esta organización';
    end if;
  else
    if not public.is_superadmin() then
      raise exception 'Solo el superadmin puede invitar administradores de una organización';
    end if;
  end if;

  if not exists (select 1 from public.organizations where id = target_org_id) then
    raise exception 'Organización inválida';
  end if;

  insert into public.org_admin_invites (organization_id, created_by, role)
  values (target_org_id, auth.uid(), p_role)
  returning token into v_token;

  return v_token;
end;
$$;
grant execute on function public.generar_invitacion_admin(uuid, text) to authenticated;

create or replace function public.claim_admin_invite(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite record;
  v_org_name text;
begin
  select * into v_invite from public.org_admin_invites where token = p_token and claimed_at is null;
  if v_invite.token is null then
    return jsonb_build_object('ok', false, 'error', 'El link de invitación no es válido o ya se usó.');
  end if;
  if exists (select 1 from public.profiles where id = auth.uid()) then
    return jsonb_build_object('ok', false, 'error', 'Esta cuenta ya tiene un perfil asignado.');
  end if;

  select name into v_org_name from public.organizations where id = v_invite.organization_id;

  insert into public.profiles (id, organization_id, role, full_name, email)
  values (auth.uid(), v_invite.organization_id, coalesce(v_invite.role, 'admin'), '', auth.email())
  on conflict (id) do update set organization_id = v_invite.organization_id, role = coalesce(v_invite.role, 'admin'), email = auth.email();

  update public.org_admin_invites set claimed_at = now(), claimed_by = auth.uid() where token = p_token;

  return jsonb_build_object('ok', true, 'organization_id', v_invite.organization_id, 'organization_name', v_org_name);
end;
$$;
grant execute on function public.claim_admin_invite(uuid) to authenticated;
