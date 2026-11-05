-- ============================================================
-- E-Mood — Instructivo de facturación por módulo + factura del
-- prestador al cierre de cada período
-- ============================================================
-- Cada servicio puede configurar sus propios datos de facturación
-- (CUIT, razón social, domicilio, condición de IVA/venta, convenio,
-- notas) — se usan para armar el instructivo que ve el prestador al
-- cerrar su período, con la fecha/período calculados automáticamente
-- según el ciclo (mes) que está cerrando. El prestador adjunta su
-- factura real en hh_modulo_ciclos.factura_url.
-- ============================================================

alter table if exists public.hh_servicios
  add column if not exists factura_cuit text default '',
  add column if not exists factura_razon_social text default '',
  add column if not exists factura_domicilio text default '',
  add column if not exists factura_condicion_iva text default '',
  add column if not exists factura_condicion_venta text default 'Contado',
  add column if not exists factura_descripcion text default '',
  add column if not exists factura_notas text default '';

alter table if exists public.hh_modulo_ciclos
  add column if not exists factura_url text;
