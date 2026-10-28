-- ============================================================
-- E-Mood — Postularse a solo algunos módulos de un servicio
-- ============================================================
-- Cuando un servicio está compuesto por más de un módulo (ver
-- 20261028_modulos_compuestos_servicio.sql), el prestador puede
-- elegir postularse solo a una parte (ej: solo el turno mañana) en
-- vez de comprometerse a todos. La elección se guarda en la
-- postulación y se copia al módulo asignado cuando se acepta.
-- ============================================================

alter table if exists public.hh_postulaciones
  add column if not exists modulos_elegidos text not null default '[]';

alter table if exists public.hh_modulos_asignados
  add column if not exists modulos_elegidos text not null default '[]';
