-- ============================================================
-- E-Mood — CV del prestador
-- ============================================================
-- Se carga desde "Mi perfil" (bucket prestador-docs, ya existente),
-- igual que ya se hace con el CBU, CUIL y foto. Es un campo
-- opcional: no se exige para postularse ni se incluye en el
-- checklist de "perfil completo".
-- ============================================================

alter table if exists public.hh_prestadores
  add column if not exists cv_url text;
