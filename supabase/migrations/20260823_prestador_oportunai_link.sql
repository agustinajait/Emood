-- ============================================================
-- E-Mood — Link de perfil en OportunAI en el alta del prestador
-- ============================================================

alter table if exists public.hh_prestadores
  add column if not exists oportunai_link text;
