-- ============================================================
-- E-Mood — Módulos de horas variables
-- ============================================================
-- Algunos módulos (ej: Coach, Líder pedagógica en Caiipli) no tienen
-- una cantidad de horas fija por jornada — varía día a día según,
-- por ejemplo, cuántos chicos hay presentes. Para esos casos, el
-- pago del ciclo (mes) ya no sale de horas_modulo × precio_hora ×
-- cantidad_por_periodo (un número fijo), sino que se calcula solo a
-- partir de las horas certificadas cada día (hora_in/hora_out de
-- hh_certificaciones) × precio_hora.
-- ============================================================

alter table if exists public.hh_servicios
  add column if not exists horas_variables boolean not null default false;
