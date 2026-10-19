-- ============================================================
-- E-Mood — El alta de prestador ya tiene el email (es el mismo con
-- el que se registró): no hace falta pedírselo de nuevo en "Mis datos".
-- ============================================================
-- create_prestador_account() guardaba el email en profiles.email pero
-- NO en hh_prestadores.email, que es el campo que usa el resto de la
-- app (perfil, postulaciones, etc.) — por eso "Mis datos" aparecía con
-- el email vacío y lo volvía a pedir. Se completa acá, en el alta.
-- ============================================================

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

  insert into public.hh_prestadores (id, nombre, contacto, drive_link, email, activo, created_at)
  values (new_prestador_id, trim(nombre), coalesce(contacto,''), coalesce(drive_link,''), auth.email(), true, now());

  insert into public.profiles (id, organization_id, role, full_name, email, prestador_id)
  values (auth.uid(), null, 'prestador', trim(nombre), auth.email(), new_prestador_id);

  return new_prestador_id;
end;
$$;
grant execute on function public.create_prestador_account(text, text, text) to authenticated;

-- Backfill: a los prestadores que ya existen y no tienen email cargado
-- en hh_prestadores, pero sí tienen una cuenta vinculada en profiles,
-- les copiamos el email desde ahí.
update public.hh_prestadores p
set email = pr.email
from public.profiles pr
where pr.prestador_id = p.id
  and coalesce(p.email, '') = ''
  and coalesce(pr.email, '') <> '';
