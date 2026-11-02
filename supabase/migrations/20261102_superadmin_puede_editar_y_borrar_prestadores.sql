-- ============================================================
-- E-Mood — El superadmin se quedó pudiendo VER a todos los
-- prestadores (migración anterior) pero no editarlos ni borrarlos
-- ============================================================
-- Al agregar "or is_superadmin()" a hh_prestadores_select para que
-- viera también a los que no se postularon a ninguna organización,
-- faltó agregar la misma rama a UPDATE y DELETE — por eso el
-- superadmin podía VER a un prestador sin postulaciones pero el
-- borrado le fallaba (0 filas, bloqueado por la misma condición de
-- siempre: postulación o módulo con la organización en la que está
-- "parado").
-- ============================================================

drop policy if exists hh_prestadores_update on public.hh_prestadores;
create policy hh_prestadores_update on public.hh_prestadores for update using (
  id = public.my_prestador_id()
  or public.is_superadmin()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.prestador_id = hh_prestadores.id and ma.organization_id = public.current_org_id())
);

drop policy if exists hh_prestadores_delete on public.hh_prestadores;
create policy hh_prestadores_delete on public.hh_prestadores for delete using (
  id = public.my_prestador_id()
  or public.is_superadmin()
  or exists (select 1 from public.hh_postulaciones po where po.prestador_id = hh_prestadores.id and po.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_modulos_asignados ma where ma.prestador_id = hh_prestadores.id and ma.organization_id = public.current_org_id())
);
