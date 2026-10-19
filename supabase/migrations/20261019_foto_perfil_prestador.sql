-- ============================================================
-- E-Mood — Foto de perfil del prestador
-- ============================================================
-- Se sube desde "Mi perfil" (bucket prestador-docs, ya existente) y
-- se muestra como avatar: en el topbar del prestador, en la tarjeta
-- "Mi perfil" y en la lista de prestadores del admin.
-- ============================================================

alter table if exists public.hh_prestadores
  add column if not exists foto_url text;
