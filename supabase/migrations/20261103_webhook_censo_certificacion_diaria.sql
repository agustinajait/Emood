-- ============================================================
-- E-Mood — El webhook de Censo Flash no impactaba en el pago
-- ============================================================
-- registrar_cierre_censo() ya marcaba el ítem "Jornada de servicio"
-- del protocolo como cumplido (hh_modulo_items), pero NUNCA tocaba
-- hh_certificaciones — la tabla de "días trabajados" que es la que
-- de verdad alimenta el cálculo de Órdenes de pago para un módulo que
-- cobra por hora certificada (horasVariables). Resultado: el webhook
-- corría, pero no impactaba en lo que se le terminaba pagando al
-- prestador.
--
-- Censo Flash y Umbral 0 pagan por jornada (no exige hora exacta de
-- entrada/salida) y cada jornada equivale a 4 horas — así que acá
-- simplemente se certifica el día con una duración fija de 4hs
-- (medianoche a medianoche+4hs, en UTC) cuando llega el reporte de
-- cierre. Si el mismo día se reporta más de una vez (reintento), se
-- actualiza en vez de duplicar (unique constraint por
-- modulo_asignado_id + fecha + modulo_idx).
-- ============================================================

create or replace function public.registrar_cierre_censo(
  p_secret uuid,
  p_dupla text,
  p_fecha date,
  p_responsable text default '',
  p_horario text default '',
  p_cantidad_registros text default '',
  p_inconvenientes text default '',
  p_situaciones_urgentes text default '',
  p_observaciones text default ''
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_modulo record;
  v_servicio record;
  v_ciclo_id text;
  v_periodo text := to_char(p_fecha, 'YYYY-MM');
  v_item_id text;
  v_nota text;
  v_actualizados int := 0;
  v_protocolo jsonb;
  v_proto_item jsonb;
  v_cantidad int;
  v_i int;
begin
  if p_dupla is null or btrim(p_dupla) = '' then
    return jsonb_build_object('ok', false, 'error', 'falta dupla');
  end if;

  select id into v_org_id from public.organizations where webhook_secret = p_secret;
  if v_org_id is null then
    return jsonb_build_object('ok', false, 'error', 'secret inválido');
  end if;

  v_nota := 'Reporte Censo Flash — ' || p_fecha::text;
  if coalesce(p_responsable,'') <> '' then v_nota := v_nota || ' · Responsable: ' || p_responsable; end if;
  if coalesce(p_horario,'') <> '' then v_nota := v_nota || ' · Horario: ' || p_horario; end if;
  if coalesce(p_cantidad_registros,'') <> '' then v_nota := v_nota || ' · Registros: ' || p_cantidad_registros; end if;
  if coalesce(p_inconvenientes,'') <> '' then v_nota := v_nota || E'\n' || 'Inconvenientes: ' || p_inconvenientes; end if;
  if coalesce(p_situaciones_urgentes,'') <> '' then v_nota := v_nota || E'\n' || 'Situaciones urgentes: ' || p_situaciones_urgentes; end if;
  if coalesce(p_observaciones,'') <> '' then v_nota := v_nota || E'\n' || 'Observaciones: ' || p_observaciones; end if;

  for v_modulo in
    select * from public.hh_modulos_asignados
    where organization_id = v_org_id and codigo_externo = btrim(p_dupla) and estado = 'en_progreso'
  loop
    select * into v_servicio from public.hh_servicios where id = v_modulo.servicio_id;

    select id into v_ciclo_id from public.hh_modulo_ciclos
      where modulo_asignado_id = v_modulo.id and periodo = v_periodo;

    if v_ciclo_id is null then
      v_ciclo_id := encode(gen_random_bytes(9), 'hex');
      insert into public.hh_modulo_ciclos (id, organization_id, modulo_asignado_id, periodo, estado, created_at, updated_at)
      values (v_ciclo_id, v_org_id, v_modulo.id, v_periodo, 'en_progreso', now(), now());

      v_protocolo := coalesce(v_modulo.protocolo::jsonb, '[]'::jsonb);
      for v_proto_item in select * from jsonb_array_elements(v_protocolo)
      loop
        if coalesce(v_proto_item->>'tipo','tarea') = 'jornada' then
          v_cantidad := greatest(1, coalesce(v_servicio.cantidad_por_periodo, 1));
          for v_i in 1..v_cantidad loop
            insert into public.hh_modulo_items (id, organization_id, modulo_asignado_id, ciclo_id, item, descripcion, tipo, estado, created_at, updated_at)
            values (encode(gen_random_bytes(9),'hex'), v_org_id, v_modulo.id, v_ciclo_id,
              (v_proto_item->>'item') || ' — Jornada ' || v_i || ' de ' || v_cantidad,
              coalesce(v_proto_item->>'descripcion',''), 'jornada', 'pendiente', now(), now());
          end loop;
        else
          insert into public.hh_modulo_items (id, organization_id, modulo_asignado_id, ciclo_id, item, descripcion, tipo, estado, created_at, updated_at)
          values (encode(gen_random_bytes(9),'hex'), v_org_id, v_modulo.id, v_ciclo_id,
            v_proto_item->>'item', coalesce(v_proto_item->>'descripcion',''), 'tarea', 'pendiente', now(), now());
        end if;
      end loop;
    end if;

    select id into v_item_id from public.hh_modulo_items
      where ciclo_id = v_ciclo_id and tipo = 'jornada' and hora_cierre is null
      order by created_at asc
      limit 1;

    if v_item_id is not null then
      update public.hh_modulo_items
        set hora_inicio = coalesce(hora_inicio, p_fecha::timestamptz),
            hora_cierre = now(),
            evidencia_nota = v_nota,
            estado = 'pendiente',
            comentario_org = '',
            updated_at = now()
        where id = v_item_id;
      v_actualizados := v_actualizados + 1;
    end if;

    -- Día trabajado: se certifica como una jornada de 4hs fijas (no
    -- importa la hora exacta de entrada/salida que reporte Censo
    -- Flash) — esto es lo que de verdad suma en Órdenes de pago para
    -- un módulo que cobra por hora certificada.
    insert into public.hh_certificaciones
      (id, organization_id, modulo_asignado_id, ciclo_id, fecha, modulo_idx, nota, hora_in, hora_out, created_at)
    values
      (encode(gen_random_bytes(9), 'hex'), v_org_id, v_modulo.id, v_ciclo_id, p_fecha, 1, v_nota,
       p_fecha::timestamptz, p_fecha::timestamptz + interval '4 hours', now())
    on conflict on constraint hh_certificaciones_modulo_asignado_id_fecha_modulo_idx_key
    do update set hora_in = excluded.hora_in, hora_out = excluded.hora_out, nota = excluded.nota, ciclo_id = excluded.ciclo_id;
  end loop;

  return jsonb_build_object('ok', true, 'modulos_actualizados', v_actualizados);
end;
$$;

grant execute on function public.registrar_cierre_censo(uuid, text, date, text, text, text, text, text, text) to anon;
