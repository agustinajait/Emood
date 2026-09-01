-- ============================================================
-- E-Mood — El prestador puede declarar su compañero de dupla al
-- postularse, en vez de que el admin arme la dupla a mano siempre.
-- ============================================================
-- Si ambas postulaciones (la propia y la del compañero declarado)
-- terminan aceptadas para el mismo módulo, acceptPostulacion() crea
-- (o reutiliza) la fila en hh_duplas y vincula los 2 módulos
-- asignados solo. El código externo (para el webhook) lo sigue
-- cargando el admin desde "Duplas", porque es un dato que solo la
-- organización conoce.
-- ============================================================

alter table if exists public.hh_postulaciones
  add column if not exists dupla_prestador_id text references public.hh_prestadores(id) on delete set null,
  add column if not exists dupla_rol_propio text default '',
  add column if not exists dupla_rol_companero text default '';
