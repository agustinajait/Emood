-- ============================================================
-- E-Mood — "Invitar administrador" queda exclusivo del superadmin
-- ============================================================
-- generar_invitacion_admin() dejaba que un admin ya existente de la
-- organización invitara a un colega. Se restringe a que SOLO el
-- superadmin pueda hacerlo — cada organización tiene su admin fijo,
-- pero quién es admin de qué organización lo decide el superadmin.
-- ============================================================

create or replace function public.generar_invitacion_admin(target_org_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token uuid;
begin
  if not public.is_superadmin() then
    raise exception 'Solo el superadmin puede invitar administradores de una organización';
  end if;
  if not exists (select 1 from public.organizations where id = target_org_id) then
    raise exception 'Organización inválida';
  end if;

  insert into public.org_admin_invites (organization_id, created_by)
  values (target_org_id, auth.uid())
  returning token into v_token;

  return v_token;
end;
$$;
grant execute on function public.generar_invitacion_admin(uuid) to authenticated;
