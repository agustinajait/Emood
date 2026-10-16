-- ============================================================
-- E-Mood — Webhook para que Censo Flash valide jornadas solo
-- ============================================================
-- Censo Flash identifica a cada dupla por un código en la URL
-- (?dupla=NN, shared/js/cierre-form.js), sin login. El formulario de
-- cierre (cierre.html) ya manda ese resumen a algún lado (Sheets/
-- Kobo/Airtable) — esto agrega UN llamado más, desde el mismo
-- submit, hacia esta función, para que E-Mood cierre solo la
-- "Jornada de servicio" del día sin que nadie la cargue a mano.
--
-- Piezas:
--   1) organizations.webhook_secret — un secreto por organización,
--      para que Censo Flash se autentique sin necesitar un login de
--      E-Mood (nadie más puede reportar cierres de esa organización
--      sin conocer este valor).
--   2) hh_modulos_asignados.codigo_externo — el admin lo carga a
--      mano (desde "Módulos asignados") con el mismo código de dupla
--      que usa Censo Flash. Si una dupla son 2 personas con 2
--      postulaciones/módulos asignados distintos en E-Mood, se les
--      pone el MISMO código a ambos — el webhook actualiza a todos
--      los que matcheen.
--   3) registrar_cierre_censo(...) — RPC pública (rol anon, validada
--      por el secreto) que busca el módulo asignado por
--      código_externo, asegura que exista el ciclo del mes del
--      reporte (creando sus ítems si hace falta — reimplementa acá
--      lo que crearItemsDeCiclo() hace en el cliente, porque este
--      webhook puede llegar antes de que alguien abra E-Mood ese
--      mes), y cierra la próxima "Jornada de servicio" pendiente con
--      la hora de cierre y un resumen del reporte como nota. Queda
--      en estado 'pendiente' — el admin la valida como cualquier
--      otra evidencia, no se auto-aprueba.
-- ============================================================

alter table if exists public.organizations
  add column if not exists webhook_secret uuid not null default gen_random_uuid();

alter table if exists public.hh_modulos_asignados
  add column if not exists codigo_externo text;

create index if not exists hh_modulos_asignados_codigo_externo_idx
  on public.hh_modulos_asignados (codigo_externo) where codigo_externo is not null;

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
  end loop;

  return jsonb_build_object('ok', true, 'modulos_actualizados', v_actualizados);
end;
$$;

grant execute on function public.registrar_cierre_censo(uuid, text, date, text, text, text, text, text, text) to anon;
