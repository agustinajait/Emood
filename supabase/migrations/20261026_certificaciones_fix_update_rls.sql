-- ============================================================
-- E-Mood — Arreglo: "Marcar salida" fallaba con "no se pudo
-- registrar la salida de hoy"
-- ============================================================
-- La migración original de hh_certificaciones creó políticas de
-- select/insert/delete, pero no de UPDATE. "Marcar entrada" hace un
-- insert nuevo (funciona), pero "Marcar salida" actualiza esa misma
-- fila (upsert con on_conflict=id, que evalúa la política de UPDATE)
-- y esa política no existía — Postgres rechazaba el guardado.
-- ============================================================

drop policy if exists hh_certificaciones_update on public.hh_certificaciones;
create policy hh_certificaciones_update on public.hh_certificaciones for update using (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_certificaciones.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
) with check (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_certificaciones.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);
