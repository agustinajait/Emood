-- ============================================================
-- E-Mood — Imagen de portada de la organización (además del logo)
-- ============================================================

alter table public.organizations
  add column if not exists cover_url text default '';
