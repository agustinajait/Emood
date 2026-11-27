-- ============================================================
-- E-Mood — "Operadores territoriales Umbral 0" (original + 4
-- turnos) medían por un checklist de 3 tareas mensuales en vez de
-- por el presente diario que marca cada dupla
-- ============================================================
-- Los 3 ítems del protocolo no tenían "tipo" (default 'tarea'), así
-- que el webhook de cierre de censo nunca generaba ni cerraba
-- ítems de jornada para estos módulos -- certificaba bien el
-- presente en hh_certificaciones, pero Seguimiento mensual y
-- Liquidación seguían viendo 0/3 ítems aprobados para siempre.
--
-- 1) Cambia el protocolo (en el servicio y en cada módulo ya
--    asignado) a un solo ítem tipo 'jornada', que es lo que el
--    webhook sabe generar/cerrar automáticamente un día a la vez.
-- 2) Recupera noviembre: por cada ciclo de estos módulos, borra los
--    3 ítems "tarea" que quedaron pendientes y los reemplaza por
--    los ítems de jornada que debieron existir desde el principio
--    -- aprobados para los días que ya tienen certificación real en
--    hh_certificaciones (con su fecha real), pendientes para el
--    resto del mes.
-- ============================================================

-- 1a) Protocolo del servicio (para las próximas asignaciones)
update public.hh_servicios
set protocolo = '[{"item":"Jornada de operador territorial Umbral 0","descripcion":"Relevamiento diario en polígono asignado, alta de casos en plataforma de GCBA (KOBO) y carga de informes sociales según protocolo en plataforma Umbral 0.","tipo":"jornada"}]'
where id in (
  'gsz9xzysjzk0',
  '130a0c5ff7b94afa90e21ea9023fcc9c',
  '30d021feff4f4a4daf9416540283a1aa',
  '89beabca9cd14ac2a5982390874fba8c',
  'bb7e471cc7f14bf3baeba459511745bf'
);

-- 1b) Protocolo ya copiado en cada módulo asignado existente (el
--     webhook lee este campo, no el del servicio)
update public.hh_modulos_asignados ma
set protocolo = '[{"item":"Jornada de operador territorial Umbral 0","descripcion":"Relevamiento diario en polígono asignado, alta de casos en plataforma de GCBA (KOBO) y carga de informes sociales según protocolo en plataforma Umbral 0.","tipo":"jornada"}]'
where ma.servicio_id in (
  'gsz9xzysjzk0',
  '130a0c5ff7b94afa90e21ea9023fcc9c',
  '30d021feff4f4a4daf9416540283a1aa',
  '89beabca9cd14ac2a5982390874fba8c',
  'bb7e471cc7f14bf3baeba459511745bf'
);

-- 2) Backfill de noviembre: por cada ciclo de estos módulos, borrar
--    los ítems "tarea" pendientes y recrearlos como jornada.
do $$
declare
  v_org_id uuid := 'a9995322-b033-4469-8f05-c7c057a539ce';
  v_ciclo record;
  v_cantidad int;
  v_i int;
  v_dia_cert date;
begin
  for v_ciclo in
    select mc.id as ciclo_id, mc.modulo_asignado_id, s.cantidad_por_periodo
    from public.hh_modulo_ciclos mc
    join public.hh_modulos_asignados ma on ma.id = mc.modulo_asignado_id
    join public.hh_servicios s on s.id = ma.servicio_id
    where ma.servicio_id in (
      'gsz9xzysjzk0',
      '130a0c5ff7b94afa90e21ea9023fcc9c',
      '30d021feff4f4a4daf9416540283a1aa',
      '89beabca9cd14ac2a5982390874fba8c',
      'bb7e471cc7f14bf3baeba459511745bf'
    )
    and mc.periodo = '2026-11'
  loop
    delete from public.hh_modulo_items
      where ciclo_id = v_ciclo.ciclo_id and tipo = 'tarea';

    v_cantidad := greatest(1, coalesce(v_ciclo.cantidad_por_periodo, 20));

    for v_i in 1..v_cantidad loop
      v_dia_cert := null;
      select fecha into v_dia_cert from (
        select distinct fecha from public.hh_certificaciones
        where modulo_asignado_id = v_ciclo.modulo_asignado_id and ciclo_id = v_ciclo.ciclo_id
        order by fecha
        offset v_i - 1 limit 1
      ) sub;

      insert into public.hh_modulo_items
        (id, organization_id, modulo_asignado_id, ciclo_id, item, descripcion, tipo, estado,
         hora_inicio, hora_cierre, evidencia_nota, created_at, updated_at)
      values (
        replace(gen_random_uuid()::text,'-',''),
        v_org_id, v_ciclo.modulo_asignado_id, v_ciclo.ciclo_id,
        'Jornada de operador territorial — Jornada ' || v_i || ' de ' || v_cantidad,
        'Relevamiento diario en polígono asignado, alta de casos en plataforma de GCBA (KOBO) y carga de informes sociales según protocolo en plataforma Umbral 0.',
        'jornada',
        case when v_dia_cert is not null then 'aprobado' else 'pendiente' end,
        case when v_dia_cert is not null then v_dia_cert::timestamptz end,
        case when v_dia_cert is not null then v_dia_cert::timestamptz + interval '4 hours' end,
        case when v_dia_cert is not null then 'Backfill — presente ya certificado el ' || v_dia_cert::text else null end,
        now(), now()
      );
    end loop;

    if not exists (
      select 1 from public.hh_modulo_items
      where ciclo_id = v_ciclo.ciclo_id and estado <> 'aprobado'
    ) then
      update public.hh_modulo_ciclos set estado = 'completado', updated_at = now()
        where id = v_ciclo.ciclo_id and estado = 'en_progreso';
    end if;
  end loop;
end $$;
