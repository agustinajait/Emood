-- ============================================================
-- E-Mood — Umbral 0 debe pagar por los días realmente certificados,
-- no un monto fijo de mes completo
-- ============================================================
-- Con horas_variables = false, montoCiclo() paga un monto FIJO
-- (horas × precio × cantidad_por_periodo) sin importar cuántos días
-- se certificaron de verdad -- asume que siempre se completan los
-- 20 días estimados del mes. Para Umbral 0 eso no es así (hay
-- ausencias, y muchos empezaron a mitad de mes), así que hay que
-- pagar en proporción a lo certificado: horas_variables = true hace
-- que el pago sea horas certificadas (de hh_certificaciones) ×
-- precio por hora.
-- ============================================================

update public.hh_servicios
set horas_variables = true
where id in (
  'gsz9xzysjzk0',
  '130a0c5ff7b94afa90e21ea9023fcc9c',
  '30d021feff4f4a4daf9416540283a1aa',
  '89beabca9cd14ac2a5982390874fba8c',
  'bb7e471cc7f14bf3baeba459511745bf'
);
