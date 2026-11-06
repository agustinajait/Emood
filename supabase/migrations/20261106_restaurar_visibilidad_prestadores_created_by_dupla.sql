-- ============================================================
-- E-Mood — Restaurar visibilidad de prestadores por created_by_org_id
-- y por dupla, perdida sin querer al agregar is_superadmin()
-- ============================================================
-- hh_prestadores_select pasó por varias versiones:
--   20260819: organization_id (vía postulación/módulo) o prestador propio
--   20260901: + visible si está en una dupla de esa organización
--   20260903: + visible si created_by_org_id = la organización (para
--             prestadores dados de alta directo, sin postulación)
--   20261102: agregó "or is_superadmin()" pero redefinió la política
--             desde una base más vieja — sin darse cuenta, volvió a
--             sacar las dos condiciones de arriba (dupla y
--             created_by_org_id). Un prestador que SOLO estuviera
--             vinculado por esas dos vías quedó invisible para su
--             propia organización desde esa fecha.
-- Esta migración junta las cuatro condiciones en una sola política.
-- ============================================================

drop policy if exists hh_prestadores_select on public.hh_prestadores;
create policy hh_prestadores_select on public.hh_prestadores for select using (
  id = public.my_prestador_id()
  or public.is_superadmin()
  or created_by_org_id = public.current_org_id()
  or exists (select 1 from public.hh_postulaciones po where po.prestador_id = hh_prestadores.id and po.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_modulos_asignados ma where ma.prestador_id = hh_prestadores.id and ma.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_duplas d where (d.prestador_id_1 = hh_prestadores.id or d.prestador_id_2 = hh_prestadores.id) and d.organization_id = public.current_org_id())
);
