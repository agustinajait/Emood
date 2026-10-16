-- ============================================================
-- E-Mood — Ítems de protocolo tipo "Jornada de trabajo"
-- ============================================================
-- Para módulos de trabajo de campo (ej: Censo Flash) donde lo que
-- hay que validar no es una lista de tareas distintas sino que cada
-- día trabajado tenga inicio, cierre y una evidencia. Convive con el
-- ítem genérico "tarea" que ya existía (checklist libre).
--
-- El ítem del protocolo (guardado como JSON dentro de hh_servicios y
-- hh_modulos_asignados) suma un campo "tipo": 'tarea' | 'jornada' —
-- no requiere migración porque protocolo se guarda como texto/JSON.
-- Lo que sí necesita columnas nuevas es hh_modulo_items, que es
-- donde vive cada instancia real (una fila por jornada del período).
-- ============================================================

alter table if exists public.hh_modulo_items
  add column if not exists tipo text not null default 'tarea',
  add column if not exists hora_inicio timestamptz,
  add column if not exists hora_cierre timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'hh_modulo_items_tipo_check'
  ) then
    alter table public.hh_modulo_items
      add constraint hh_modulo_items_tipo_check check (tipo in ('tarea','jornada'));
  end if;
end $$;
