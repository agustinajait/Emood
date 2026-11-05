-- ============================================================
-- E-Mood — El superadmin pueda ver TODOS los módulos activos de un
-- prestador, sean de la organización en la que está "parado" o de
-- cualquier otra
-- ============================================================
-- El superadmin ya veía a TODOS los prestadores (migración
-- 20261102_superadmin_ve_todos_los_prestadores.sql), pero las tablas
-- de servicios/postulaciones/módulos asignados/ciclos/certificaciones
-- seguían filtradas solo por la organización en la que está parado
-- (switch_superadmin_org) — así que el detalle de un prestador le
-- mostraba nada más que los módulos de ESA organización, no el perfil
-- completo con todo lo que tiene activo en cualquier organización.
-- ============================================================

drop policy if exists hh_servicios_select on public.hh_servicios;
create policy hh_servicios_select on public.hh_servicios for select using (
  organization_id = public.current_org_id()
  or public.is_superadmin()
  or (estado = 'activo' and visibilidad = 'publico')
  or exists (select 1 from public.hh_postulaciones po where po.servicio_id = hh_servicios.id and po.prestador_id = public.my_prestador_id())
  or exists (select 1 from public.hh_modulos_asignados ma where ma.servicio_id = hh_servicios.id and ma.prestador_id = public.my_prestador_id())
);

drop policy if exists hh_postulaciones_select on public.hh_postulaciones;
create policy hh_postulaciones_select on public.hh_postulaciones for select using (
  organization_id = public.current_org_id()
  or public.is_superadmin()
  or prestador_id = public.my_prestador_id()
);

drop policy if exists hh_modulos_asignados_select on public.hh_modulos_asignados;
create policy hh_modulos_asignados_select on public.hh_modulos_asignados for select using (
  organization_id = public.current_org_id()
  or public.is_superadmin()
  or prestador_id = public.my_prestador_id()
);

drop policy if exists hh_modulo_items_select on public.hh_modulo_items;
create policy hh_modulo_items_select on public.hh_modulo_items for select using (
  organization_id = public.current_org_id()
  or public.is_superadmin()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_items.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

drop policy if exists hh_modulo_ciclos_select on public.hh_modulo_ciclos;
create policy hh_modulo_ciclos_select on public.hh_modulo_ciclos for select using (
  organization_id = public.current_org_id()
  or public.is_superadmin()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_ciclos.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

drop policy if exists hh_certificaciones_select on public.hh_certificaciones;
create policy hh_certificaciones_select on public.hh_certificaciones for select using (
  organization_id = public.current_org_id()
  or public.is_superadmin()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_certificaciones.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);
