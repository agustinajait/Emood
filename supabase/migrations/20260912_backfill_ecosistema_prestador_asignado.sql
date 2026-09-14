-- ============================================================
-- E-Mood — Backfill puntual: completar el ecosistema de los
-- prestadores que ya quedaron asignados a un módulo directo
-- (antes de que asignarPrestadorDirecto() empezara a copiarlo solo).
-- ============================================================

update public.hh_prestadores p
set ecosistema_id = s.ecosistema_id
from public.hh_modulos_asignados ma
join public.hh_servicios s on s.id = ma.servicio_id
where ma.prestador_id = p.id
  and ma.estado = 'en_progreso'
  and s.ecosistema_id is not null
  and (p.ecosistema_id is distinct from s.ecosistema_id);
