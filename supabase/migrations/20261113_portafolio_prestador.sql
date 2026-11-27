-- ============================================================
-- E-Mood — "CV" pasa a presentarse como Portafolio
-- ============================================================
-- En vez de encuadrar al prestador en la lógica de búsqueda
-- laboral tradicional (un "CV" que se sube y listo), ahora puede
-- contar su rol/especialidad y un proyecto en el que trabajó, en
-- sus propias palabras — orientado a mostrar capacidad de acción,
-- no a buscar empleo. El archivo adjunto (antes "CV", columna
-- cv_url que ya existe) se mantiene como documento opcional del
-- portafolio (ej: una muestra de trabajo, un certificado).
-- ============================================================

alter table public.hh_prestadores
  add column if not exists portafolio_rol text not null default '',
  add column if not exists portafolio_proyecto text not null default '';
