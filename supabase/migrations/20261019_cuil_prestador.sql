-- ============================================================
-- E-Mood — Número de CUIL y constancia de CUIL del prestador
-- ============================================================
-- Se cargan desde "Mi perfil" (bucket prestador-docs, ya existente),
-- igual que ya se hace con el CBU y su constancia.
-- ============================================================

alter table if exists public.hh_prestadores
  add column if not exists numero_cuil text,
  add column if not exists cuil_comprobante_url text;
