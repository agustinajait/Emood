-- ============================================================
-- E-Mood — Un prestador cargado por "Importar duplas" debe seguir
-- siendo visible para la organización que lo cargó, aunque todavía
-- no tenga ninguna postulación ni módulo asignado.
-- ============================================================
-- "Importar duplas" crea al prestador y la fila de hh_duplas, pero
-- A PROPÓSITO no crea ninguna postulación/módulo asignado (para que
-- esa gente quede libre de postularse a cualquier cliente, no solo
-- al que la cargó). El problema: hh_prestadores_select solo daba
-- visibilidad vía postulación o módulo asignado — sin ninguna de
-- las dos, el prestador recién creado quedaba invisible para su
-- propia organización en la siguiente recarga (parecía "borrado",
-- aunque seguía intacto en la base).
-- ============================================================

drop policy if exists hh_prestadores_select on public.hh_prestadores;
create policy hh_prestadores_select on public.hh_prestadores for select using (
  id = public.my_prestador_id()
  or exists (select 1 from public.hh_postulaciones po where po.prestador_id = hh_prestadores.id and po.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_modulos_asignados ma where ma.prestador_id = hh_prestadores.id and ma.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_duplas d where (d.prestador_id_1 = hh_prestadores.id or d.prestador_id_2 = hh_prestadores.id) and d.organization_id = public.current_org_id())
);
