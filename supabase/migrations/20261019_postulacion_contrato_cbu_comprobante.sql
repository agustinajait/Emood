-- ============================================================
-- E-Mood — Aceptar el tipo de contrato del módulo al postularse +
-- constancia de CBU/CVU del prestador.
-- ============================================================
-- 1) hh_postulaciones.tipo_contrato_aceptado: cuando el módulo pide
--    un tipo de contrato (Monotributo, Relación de dependencia, etc.),
--    el prestador tiene que tildar que lo acepta antes de poder
--    postularse — queda guardado acá como registro de esa aceptación.
-- 2) hh_prestadores.cbu_comprobante_url: además de cargar el CBU/alias
--    a mano, el prestador puede adjuntar una constancia (captura del
--    banco/billetera) desde "Mis datos".
-- ============================================================

alter table if exists public.hh_postulaciones
  add column if not exists tipo_contrato_aceptado text;

alter table if exists public.hh_prestadores
  add column if not exists cbu_comprobante_url text;
