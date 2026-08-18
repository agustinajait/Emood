-- ============================================================
-- E-Mood — Un prestador pertenece a un ecosistema (proyecto).
-- Una organización puede tener varios ecosistemas, cada uno con
-- sus propios prestadores.
-- ============================================================

alter table if exists public.hh_prestadores
  add column if not exists ecosistema_id text;
