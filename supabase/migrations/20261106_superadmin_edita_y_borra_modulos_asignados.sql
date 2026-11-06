-- ============================================================
-- E-Mood — El superadmin pueda EDITAR/BORRAR módulos asignados y
-- postulaciones de cualquier organización, no solo la que está
-- "parado"
-- ============================================================
-- hh_modulos_asignados_select y hh_postulaciones_select ya tienen
-- "or is_superadmin()" (20261105_superadmin_ve_modulos_de_todas_las_
-- organizaciones.sql) — el superadmin ya VE los módulos asignados de
-- cualquier organización. Pero UPDATE y DELETE de esas dos tablas
-- quedaron en su versión original (solo organization_id =
-- current_org_id()), así que "Eliminar asignación" / "Cambiar de
-- módulo" le fallaban en silencio (0 filas afectadas, sin error) para
-- cualquier módulo que no fuera de la organización en la que está
-- parado en ese momento — mismo patrón de bug que ya se corrigió para
-- hh_prestadores en 20261102_superadmin_puede_editar_y_borrar_
-- prestadores.sql.
-- ============================================================

drop policy if exists hh_modulos_asignados_update on public.hh_modulos_asignados;
create policy hh_modulos_asignados_update on public.hh_modulos_asignados for update using (
  organization_id = public.current_org_id() or public.is_superadmin()
) with check (
  organization_id = public.current_org_id() or public.is_superadmin()
);

drop policy if exists hh_modulos_asignados_delete on public.hh_modulos_asignados;
create policy hh_modulos_asignados_delete on public.hh_modulos_asignados for delete using (
  organization_id = public.current_org_id() or public.is_superadmin()
);

drop policy if exists hh_postulaciones_update on public.hh_postulaciones;
create policy hh_postulaciones_update on public.hh_postulaciones for update using (
  organization_id = public.current_org_id() or public.is_superadmin()
) with check (
  organization_id = public.current_org_id() or public.is_superadmin()
);

drop policy if exists hh_postulaciones_delete on public.hh_postulaciones;
create policy hh_postulaciones_delete on public.hh_postulaciones for delete using (
  organization_id = public.current_org_id() or public.is_superadmin()
);
