-- ============================================================
-- E-Mood — Certificación diaria del prestador (control de
-- asistencia, sin llamarlo así)
-- ============================================================
-- Un prestador puede, una vez por día calendario y por cada
-- módulo asignado que tenga en curso, tocar "Certificar hoy".
-- Queda contado automáticamente (sin aprobación de la
-- organización) y sirve, junto con los ítems del protocolo, para
-- validar el módulo a fin de mes.
-- ============================================================

begin;

create table if not exists public.hh_certificaciones (
  id text primary key,
  organization_id uuid references public.organizations(id) on delete cascade,
  modulo_asignado_id text not null references public.hh_modulos_asignados(id) on delete cascade,
  ciclo_id text references public.hh_modulo_ciclos(id) on delete set null,
  fecha date not null,
  nota text default '',
  created_at timestamptz not null default now(),
  unique (modulo_asignado_id, fecha)
);

alter table public.hh_certificaciones enable row level security;

drop policy if exists hh_certificaciones_select on public.hh_certificaciones;
create policy hh_certificaciones_select on public.hh_certificaciones for select using (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_certificaciones.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

drop policy if exists hh_certificaciones_insert on public.hh_certificaciones;
create policy hh_certificaciones_insert on public.hh_certificaciones for insert with check (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_certificaciones.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

drop policy if exists hh_certificaciones_delete on public.hh_certificaciones;
create policy hh_certificaciones_delete on public.hh_certificaciones for delete using (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_certificaciones.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

commit;
