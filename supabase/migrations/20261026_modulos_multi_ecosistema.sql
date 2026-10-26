-- ============================================================
-- E-Mood — Un módulo puede pertenecer a más de un ecosistema
-- ============================================================
-- Hasta ahora tanto hh_servicios (los módulos a los que se
-- postulan los prestadores) como hh_modulos (asignación directa
-- tarea↔prestador) tenían un solo ecosistema_id: un módulo como
-- "Facilitadoras" no se podía ofrecer a la vez en, por ejemplo,
-- "Caiipli Norte" y "Caiipli Sur" sin duplicarlo.
--
-- Se agrega ecosistema_ids (texto con un array JSON de ids), con
-- el mismo patrón que ya se usa para protocolo/docs_requeridos
-- (JSON.stringify guardado como texto). Se mantiene la columna
-- vieja ecosistema_id sin tocar — ya no la usa el frontend, pero
-- no hace falta borrarla.
-- ============================================================

alter table if exists public.hh_servicios
  add column if not exists ecosistema_ids text not null default '[]';

update public.hh_servicios
set ecosistema_ids = jsonb_build_array(ecosistema_id)::text
where ecosistema_id is not null
  and coalesce(ecosistema_ids, '[]') = '[]';

alter table if exists public.hh_modulos
  add column if not exists ecosistema_ids text not null default '[]';

update public.hh_modulos
set ecosistema_ids = jsonb_build_array(ecosistema_id)::text
where ecosistema_id is not null
  and coalesce(ecosistema_ids, '[]') = '[]';
