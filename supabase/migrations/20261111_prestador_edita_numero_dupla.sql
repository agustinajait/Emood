-- ============================================================
-- E-Mood — El prestador también puede cargar/editar su número de
-- dupla (antes solo el admin, desde "Módulos asignados" o la ficha)
-- ============================================================
-- hh_modulos_asignados_update solo deja editar a organization_id =
-- current_org_id() (el admin de esa organización) o is_superadmin()
-- -- el prestador no tiene permiso para tocar su propia fila ahí
-- (ni debería, en general: podría cambiar estado, postulacion_id,
-- etc.). En vez de abrir el UPDATE entero, este RPC solo deja tocar
-- el campo codigo_externo (el número de dupla), y solo si el módulo
-- es del propio prestador, de su organización actual, o si es
-- superadmin.
-- ============================================================

create or replace function public.set_numero_dupla(p_modulo_asignado_id text, p_numero_dupla text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.hh_modulos_asignados m
    where m.id = p_modulo_asignado_id
      and (
        m.prestador_id = public.my_prestador_id()
        or m.organization_id = public.current_org_id()
        or public.is_superadmin()
      )
  ) then
    raise exception 'No tenés permiso para editar este módulo.';
  end if;

  update public.hh_modulos_asignados
  set codigo_externo = btrim(coalesce(p_numero_dupla, ''))
  where id = p_modulo_asignado_id;
end;
$$;

grant execute on function public.set_numero_dupla(text, text) to authenticated;
