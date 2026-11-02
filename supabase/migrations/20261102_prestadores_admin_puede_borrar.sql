-- ============================================================
-- E-Mood — El admin no podía borrar prestadores (se "borraban" en
-- la pantalla pero seguían en la base)
-- ============================================================
-- La política de DELETE de hh_prestadores solo dejaba borrar al
-- propio prestador su propio legajo (id = my_prestador_id()) — nunca
-- se agregó la rama que sí tienen SELECT/UPDATE para que la
-- organización pueda borrar a un prestador que se postuló o tiene
-- módulos con ella. Como PostgREST no devuelve error cuando una
-- política de RLS deja pasar el DELETE pero no matchea ninguna fila
-- (0 filas borradas = respuesta "exitosa" igual), el botón "Eliminar"
-- del admin no avisaba nada: la fila volvía a aparecer en el
-- próximo refresh sin ningún mensaje de error.
-- ============================================================

drop policy if exists hh_prestadores_delete on public.hh_prestadores;
create policy hh_prestadores_delete on public.hh_prestadores for delete using (
  id = public.my_prestador_id()
  or exists (select 1 from public.hh_postulaciones po where po.prestador_id = hh_prestadores.id and po.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_modulos_asignados ma where ma.prestador_id = hh_prestadores.id and ma.organization_id = public.current_org_id())
);
