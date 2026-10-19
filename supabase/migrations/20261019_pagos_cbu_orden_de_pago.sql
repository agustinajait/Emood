-- ============================================================
-- E-Mood — Órdenes de pago: CBU del prestador + marca de "pagado"
-- en los ciclos aprobados.
-- ============================================================
-- E-Mood NO mueve plata (no se integra con ningún banco/billetera):
-- solo arma el listado de a quién pagarle, cuánto y a qué CBU/alias,
-- a partir de los remitos ya aprobados, para que la organización lo
-- suba a su propio home banking o Mercado Pago. Esta migración solo
-- agrega los campos que hacían falta para eso:
--   1) hh_prestadores.cbu / alias_cbu — el prestador carga su propio
--      CBU/alias desde "Mis datos" (o lo caraga el admin).
--   2) hh_modulo_ciclos.pagado / fecha_pago — el admin marca un
--      remito aprobado como "ya pagado" después de hacer la
--      transferencia afuera, para que no vuelva a salir en la
--      próxima orden de pago.
-- ============================================================

alter table if exists public.hh_prestadores
  add column if not exists cbu text,
  add column if not exists alias_cbu text;

alter table if exists public.hh_modulo_ciclos
  add column if not exists pagado boolean not null default false,
  add column if not exists fecha_pago timestamptz;
