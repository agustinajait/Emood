-- ============================================================
-- E-Mood — Evitar módulos asignados duplicados por doble clic
-- ============================================================
-- acceptPostulacion() no tenía freno contra un doble clic en
-- "Aceptar" (o un reintento de red): podía crear dos filas de
-- hh_modulos_asignados a partir de la misma postulación. Ya se
-- corrigió en el cliente, pero la garantía real tiene que estar acá:
-- una postulación no puede generar más de un módulo asignado.
--
-- Es un índice único parcial (no una constraint UNIQUE común) porque
-- postulacion_id es nullable — no queremos que dos filas con
-- postulacion_id = null choquen entre sí.
-- ============================================================

-- Si ya existen duplicados en tu base (mismo postulacion_id repetido),
-- este bloque los limpia antes de crear el índice, dejando la fila más
-- vieja de cada grupo y borrando el resto (junto con sus ciclos/ítems,
-- por el "on delete cascade" ya definido en esas tablas).
delete from public.hh_modulos_asignados a
using public.hh_modulos_asignados b
where a.postulacion_id is not null
  and a.postulacion_id = b.postulacion_id
  and (a.created_at, a.id) > (b.created_at, b.id);

create unique index if not exists hh_modulos_asignados_postulacion_unica
  on public.hh_modulos_asignados (postulacion_id)
  where postulacion_id is not null;
