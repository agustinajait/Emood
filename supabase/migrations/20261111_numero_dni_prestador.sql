-- ============================================================
-- E-Mood — Número de DNI del prestador
-- ============================================================
-- Hasta ahora solo existía "tiene_dni" (un tilde de "DNI
-- presentado"), sin ningún lugar para cargar el número en sí. Se
-- agrega como campo de texto libre (no todos los documentos de
-- identidad tienen el mismo formato) en el alta/edición del
-- prestador desde el admin.
-- ============================================================

alter table if exists public.hh_prestadores add column if not exists numero_dni text default '';
