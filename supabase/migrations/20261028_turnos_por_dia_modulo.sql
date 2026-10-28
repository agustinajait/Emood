-- ============================================================
-- E-Mood — Turnos por día (roles con más de un turno diario)
-- ============================================================
-- Un rol puede implicar más de un turno en el mismo día (ej: un
-- módulo de 4hs a la mañana y otro de 4hs a la tarde). En vez de
-- duplicar el módulo y hacer que el prestador se postule dos veces,
-- el módulo declara cuántos turnos tiene por día: el prestador se
-- postula una sola vez y certifica entrada/salida de cada turno por
-- separado. El pago y las horas certificadas suman todos los turnos.
-- ============================================================

alter table if exists public.hh_servicios
  add column if not exists turnos_por_dia integer not null default 1;

alter table if exists public.hh_certificaciones
  add column if not exists turno integer not null default 1;

alter table public.hh_certificaciones drop constraint if exists hh_certificaciones_modulo_asignado_id_fecha_key;
alter table public.hh_certificaciones add constraint hh_certificaciones_modulo_asignado_id_fecha_turno_key unique (modulo_asignado_id, fecha, turno);
