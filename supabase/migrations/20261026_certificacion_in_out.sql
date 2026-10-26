-- ============================================================
-- E-Mood — Certificación diaria: entrada y salida
-- ============================================================
-- La certificación del día pasa de ser un solo toque a un simple
-- IN (entrada) y, si hace falta, OUT (salida) — más parecido a
-- cómo se vive en el día a día. El OUT es opcional: con marcar
-- la entrada el día ya queda certificado.
-- ============================================================

alter table if exists public.hh_certificaciones
  add column if not exists hora_in timestamptz,
  add column if not exists hora_out timestamptz;
