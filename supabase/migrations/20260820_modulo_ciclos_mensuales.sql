-- ============================================================
-- E-Mood — Ciclos mensuales por módulo asignado
-- ============================================================
-- Un módulo asignado (ej: 3 meses de trabajo) ahora se factura por
-- CICLO (mes): cada ciclo tiene su propia copia de los ítems del
-- protocolo, su propia evidencia/aprobación, y su propio remito.
-- Antes el remito era uno solo por todo el módulo asignado; ahora
-- es uno por mes.
-- ============================================================

begin;

create table if not exists public.hh_modulo_ciclos (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  modulo_asignado_id text not null references public.hh_modulos_asignados(id) on delete cascade,
  periodo text not null, -- 'YYYY-MM'
  estado text not null default 'en_progreso' check (estado in ('en_progreso','completado','aprobado')),
  remito_numero text,
  remito_fecha timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (modulo_asignado_id, periodo)
);

-- Los ítems de evidencia ahora cuelgan de un ciclo (mes), no
-- directamente del módulo asignado. Mantenemos modulo_asignado_id
-- también (no rompe las políticas RLS que ya existían sobre esta
-- tabla, y sirve para consultas directas).
alter table public.hh_modulo_items add column if not exists ciclo_id text references public.hh_modulo_ciclos(id) on delete cascade;

alter table public.hh_modulo_ciclos enable row level security;

drop policy if exists hh_modulo_ciclos_select on public.hh_modulo_ciclos;
create policy hh_modulo_ciclos_select on public.hh_modulo_ciclos for select using (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_ciclos.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);
drop policy if exists hh_modulo_ciclos_insert on public.hh_modulo_ciclos;
create policy hh_modulo_ciclos_insert on public.hh_modulo_ciclos for insert with check (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_ciclos.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);
drop policy if exists hh_modulo_ciclos_update on public.hh_modulo_ciclos;
create policy hh_modulo_ciclos_update on public.hh_modulo_ciclos for update using (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_ciclos.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

commit;
