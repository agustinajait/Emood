-- ============================================================
-- E-Mood — El superadmin ve TODOS los prestadores registrados,
-- se hayan postulado a alguna organización o no
-- ============================================================
-- Un prestador es una entidad global (puede postularse a más de una
-- organización) y hasta ahora solo era visible para una organización
-- si tenía una postulación o un módulo asignado con ella — alguien
-- que recién se registra y todavía no se postuló a nada quedaba
-- invisible para TODOS, incluido el superadmin (que solo "se para"
-- en una organización puntual, con los mismos permisos que su admin).
-- Esto agrega una vista global, solo para superadmin, que no depende
-- de a qué organización(es) se haya postulado cada uno.
-- ============================================================

drop policy if exists hh_prestadores_select on public.hh_prestadores;
create policy hh_prestadores_select on public.hh_prestadores for select using (
  id = public.my_prestador_id()
  or public.is_superadmin()
  or exists (select 1 from public.hh_postulaciones po where po.prestador_id = hh_prestadores.id and po.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_modulos_asignados ma where ma.prestador_id = hh_prestadores.id and ma.organization_id = public.current_org_id())
);
