-- ============================================================
-- E-Mood — "Número de dupla" como campo libre en la postulación
-- ============================================================
-- Reemplaza, de cara al prestador, el mecanismo de "elegí a tu
-- compañero/a de una lista" por un casillero de texto simple y
-- opcional: el número/código de dupla que ya le asignaron afuera
-- (ej: en Censo Flash). El admin lo usa para correlacionar a los 2
-- integrantes a mano — no arma ninguna relación automática en la
-- base, es solo un dato informativo.
-- ============================================================

alter table public.hh_postulaciones
  add column if not exists numero_dupla text default '';
