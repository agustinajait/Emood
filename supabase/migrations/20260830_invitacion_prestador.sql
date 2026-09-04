-- ============================================================
-- E-Mood — Link de invitación para que un prestador ya cargado
-- (ej: por importación de nómina) se vincule a su propio login.
-- ============================================================
-- El admin carga al prestador sin cuenta (por "Nuevo prestador" o
-- por importación). Genera un link de invitación de un solo uso; la
-- persona entra, crea su email/contraseña, y queda vinculada al
-- MISMO registro (profiles.prestador_id apunta ahí) en vez de
-- crearse un prestador nuevo por separado. Después completa sus
-- datos desde "Mis datos", que ya existe.
-- ============================================================

alter table public.hh_prestadores
  add column if not exists invite_token uuid,
  add column if not exists invite_claimed_at timestamptz;

create unique index if not exists hh_prestadores_invite_token_idx
  on public.hh_prestadores (invite_token) where invite_token is not null;

-- Genera (o regenera) el token de invitación de un prestador. Solo
-- puede hacerlo una organización que ya tenga relación con él
-- (postulación o módulo asignado) — mismo criterio que ya usa
-- hh_prestadores_select/update — y solo si todavía no tiene una
-- cuenta vinculada.
create or replace function public.generar_invitacion_prestador(p_prestador_id text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token uuid;
begin
  if not exists (
    select 1 from public.hh_modulos_asignados ma where ma.prestador_id = p_prestador_id and ma.organization_id = public.current_org_id()
    union
    select 1 from public.hh_postulaciones po where po.prestador_id = p_prestador_id and po.organization_id = public.current_org_id()
  ) then
    raise exception 'No tenés relación con este prestador';
  end if;

  if exists (select 1 from public.profiles where prestador_id = p_prestador_id) then
    raise exception 'Este prestador ya tiene una cuenta vinculada';
  end if;

  v_token := gen_random_uuid();
  update public.hh_prestadores set invite_token = v_token, invite_claimed_at = null where id = p_prestador_id;
  return v_token;
end;
$$;
grant execute on function public.generar_invitacion_prestador(text) to authenticated;

-- La usa la persona ya logueada (recién creó su cuenta) para
-- vincularse al prestador del token. Un solo uso: lo consume al
-- final.
create or replace function public.claim_prestador_invite(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prestador record;
begin
  select * into v_prestador from public.hh_prestadores where invite_token = p_token and invite_claimed_at is null;
  if v_prestador.id is null then
    return jsonb_build_object('ok', false, 'error', 'El link de invitación no es válido o ya se usó.');
  end if;
  if exists (select 1 from public.profiles where prestador_id = v_prestador.id) then
    return jsonb_build_object('ok', false, 'error', 'Este prestador ya tiene una cuenta vinculada.');
  end if;

  insert into public.profiles (id, organization_id, role, full_name, email, prestador_id)
  values (auth.uid(), null, 'prestador', v_prestador.nombre, auth.email(), v_prestador.id)
  on conflict (id) do update set role = 'prestador', full_name = v_prestador.nombre, email = auth.email(), prestador_id = v_prestador.id;

  update public.hh_prestadores set invite_claimed_at = now(), invite_token = null where id = v_prestador.id;

  return jsonb_build_object('ok', true, 'prestador_id', v_prestador.id, 'nombre', v_prestador.nombre);
end;
$$;
grant execute on function public.claim_prestador_invite(uuid) to authenticated;
