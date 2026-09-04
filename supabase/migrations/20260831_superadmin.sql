-- ============================================================
-- E-Mood — Rol superadmin: gestiona varias organizaciones cliente
-- ============================================================
-- En vez de agregar "or is_superadmin()" a cada política de cada
-- tabla (docenas de lugares, fácil de olvidar alguno), el superadmin
-- literalmente SE VUELVE miembro de la organización que elige en el
-- selector — se le actualiza su propio profiles.organization_id.
-- Así current_org_id() (de la que dependen TODAS las políticas y
-- funciones existentes) ya funciona sin tocar nada más: mientras
-- está "parado en" una organización, el sistema lo trata igual que
-- al admin de esa organización. Puede cambiar de organización
-- cuando quiera desde el selector.
-- ============================================================

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('admin','socio','prestador','superadmin'));

create or replace function public.is_superadmin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select role = 'superadmin' from public.profiles where id = auth.uid()), false);
$$;

-- El superadmin necesita ver la lista COMPLETA de organizaciones
-- para poder elegir con cuál trabajar (el resto de los usuarios solo
-- ve la propia, como siempre).
drop policy if exists org_select on public.organizations;
create policy org_select on public.organizations for select
  using (id = public.current_org_id() or public.is_superadmin());

-- "Entrar" a una organización: valida que quien llama sea realmente
-- superadmin (si no, cualquiera podría auto-asignarse a cualquier
-- organización) y actualiza su propio perfil.
create or replace function public.switch_superadmin_org(target_org_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_superadmin() then
    raise exception 'Solo un superadmin puede cambiar de organización';
  end if;
  if not exists (select 1 from public.organizations where id = target_org_id) then
    raise exception 'Organización inválida';
  end if;
  update public.profiles set organization_id = target_org_id where id = auth.uid();
end;
$$;
grant execute on function public.switch_superadmin_org(uuid) to authenticated;

-- ── Para promoverte a vos misma a superadmin, corré esto aparte
--    (reemplazando el email si hace falta) — no lo hace esta
--    migración sola porque es un dato, no un cambio de esquema:
--
-- update public.profiles
-- set role = 'superadmin'
-- where id = (select id from auth.users where email = 'a.jait@inclusioncaii.org');
