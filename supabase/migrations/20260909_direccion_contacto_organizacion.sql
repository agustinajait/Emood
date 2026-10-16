-- ============================================================
-- E-Mood — Dirección y contacto en el perfil público de la
-- organización (se suman a bio/logo/sitio web de 20260906).
-- ============================================================

alter table public.organizations
  add column if not exists direccion text default '',
  add column if not exists contacto text default '';
