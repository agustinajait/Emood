-- ============================================================
-- E-Mood — Invitar a un admin propio para una organización
-- ============================================================
-- Hasta ahora la única forma de administrar una organización ya
-- creada era que el superadmin "se pare" en ella con su propio
-- login — no había manera de darle a alguien de esa organización
-- (ej: Caii) su PROPIO usuario admin, separado del superadmin.
--
-- Este link funciona igual que la invitación de prestador: el
-- superadmin (o un admin ya existente de esa organización) genera
-- un link de un solo uso; la persona invitada crea su email/
-- contraseña y queda como admin PERMANENTE de esa organización
-- (no puede cambiar de organización — eso sigue siendo exclusivo
-- del superadmin).
-- ============================================================

create table if not exists public.org_admin_invites (
  token uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  claimed_by uuid references auth.users(id)
);

alter table public.org_admin_invites enable row level security;

-- Solo el superadmin o un admin ya existente de esa organización
-- pueden ver/generar sus propias invitaciones.
drop policy if exists org_admin_invites_select on public.org_admin_invites;
create policy org_admin_invites_select on public.org_admin_invites for select using (
  organization_id = public.current_org_id() or public.is_superadmin()
);

-- Genera (o regenera) un link de invitación para admin de una
-- organización. Devuelve el token.
create or replace function public.generar_invitacion_admin(target_org_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token uuid;
begin
  if not (public.is_superadmin() or target_org_id = public.current_org_id()) then
    raise exception 'No tenés permiso para invitar administradores de esta organización';
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

-- La usa la persona ya logueada (recién creó su cuenta) para
-- quedar como admin de la organización del token. Un solo uso.
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
  values (auth.uid(), v_invite.organization_id, 'admin', '', auth.email())
  on conflict (id) do update set organization_id = v_invite.organization_id, role = 'admin', email = auth.email();

  update public.org_admin_invites set claimed_at = now(), claimed_by = auth.uid() where token = p_token;

  return jsonb_build_object('ok', true, 'organization_id', v_invite.organization_id, 'organization_name', v_org_name);
end;
$$;
grant execute on function public.claim_admin_invite(uuid) to authenticated;
