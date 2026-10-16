-- ============================================================
-- E-Mood — Un módulo puede ser público o privado
-- ============================================================
-- "Activo" ya controlaba si el módulo acepta postulaciones nuevas
-- (pausado/reactivado). Esto agrega un segundo control ortogonal:
-- un módulo activo puede seguir siendo de convocatoria PÚBLICA
-- (aparece en la home, en el perfil de la organización y en
-- "Módulos disponibles" de cualquier prestador) o PRIVADA (sigue
-- funcionando igual — postulaciones, evidencia, remitos — pero no
-- se publica; solo llega gente por asignación directa).
--
-- La RLS de lectura queda alineada: un módulo privado deja de ser
-- visible para el resto del mundo (antes cualquier "activo" era
-- visible para cualquiera, logueado o no), pero un prestador que
-- YA tiene una postulación o un módulo asignado ahí lo sigue
-- viendo siempre, sea público o privado — si no, se le rompería
-- "Módulo eliminado" en su propio panel.
-- ============================================================

alter table public.hh_servicios
  add column if not exists visibilidad text not null default 'publico' check (visibilidad in ('publico','privado'));

drop policy if exists hh_servicios_select on public.hh_servicios;
create policy hh_servicios_select on public.hh_servicios for select using (
  organization_id = public.current_org_id()
  or (estado = 'activo' and visibilidad = 'publico')
  or exists (select 1 from public.hh_postulaciones po where po.servicio_id = hh_servicios.id and po.prestador_id = public.my_prestador_id())
  or exists (select 1 from public.hh_modulos_asignados ma where ma.servicio_id = hh_servicios.id and ma.prestador_id = public.my_prestador_id())
);
