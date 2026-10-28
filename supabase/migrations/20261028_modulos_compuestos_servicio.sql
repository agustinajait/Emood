-- ============================================================
-- E-Mood — Un servicio compuesto por varios módulos
-- ============================================================
-- Reemplaza el intento anterior ("turnos por día", migración
-- 20261028_turnos_por_dia_modulo.sql — si llegaste a correrla, esta
-- la deja sin efecto). Un servicio publicado puede estar compuesto
-- por más de un módulo (ej: Líder pedagógica = 2 módulos de 4hs),
-- cada uno con su propia cantidad de horas. El prestador se postula
-- una sola vez al servicio y certifica entrada/salida de cada
-- módulo por separado; el pago y las horas certificadas suman todos
-- los módulos del servicio.
-- ============================================================

alter table if exists public.hh_servicios drop column if exists turnos_por_dia;
alter table if exists public.hh_servicios
  add column if not exists modulos_horas text not null default '[]';

alter table if exists public.hh_certificaciones drop column if exists turno;
alter table if exists public.hh_certificaciones
  add column if not exists modulo_idx integer not null default 1;

alter table public.hh_certificaciones drop constraint if exists hh_certificaciones_modulo_asignado_id_fecha_key;
alter table public.hh_certificaciones drop constraint if exists hh_certificaciones_modulo_asignado_id_fecha_turno_key;
alter table public.hh_certificaciones add constraint hh_certificaciones_modulo_asignado_id_fecha_modulo_idx_key unique (modulo_asignado_id, fecha, modulo_idx);
