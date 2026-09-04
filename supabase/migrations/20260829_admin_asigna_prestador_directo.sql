-- ============================================================
-- E-Mood — El admin puede asignar un prestador a un módulo
-- directamente al importar una nómina (sin pasar por postularse).
-- ============================================================
-- hh_postulaciones_insert exigía prestador_id = my_prestador_id(),
-- porque hasta ahora una postulación siempre la creaba el propio
-- prestador al aplicar. Para poder cargar una nómina completa (ej:
-- CPI Norte) y asignarla directo a un módulo, el admin necesita
-- poder crear la postulación (ya "aceptada") en nombre del
-- prestador — mismo patrón que ya usa hh_modulo_items_insert
-- (org O prestador dueño).
-- ============================================================

drop policy if exists hh_postulaciones_insert on public.hh_postulaciones;
create policy hh_postulaciones_insert on public.hh_postulaciones for insert with check (
  prestador_id = public.my_prestador_id()
  or organization_id = public.current_org_id()
);
