-- ============================================================
-- E-Mood — Duplas (equipos de 2 prestadores, ej: chofer + operador)
-- ============================================================
-- No reemplaza el modelo "1 prestador = 1 postulación = 1 módulo
-- asignado" (eso sostiene RLS, evidencia y aprobación por persona).
-- La dupla es una capa de agrupación arriba: junta a los 2
-- integrantes, guarda el código externo compartido (ej: número de
-- dupla en Censo Flash) y permite generar un remito combinado para
-- los casos donde factura uno solo por los dos.
-- ============================================================

create table if not exists public.hh_duplas (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  nombre text not null default '',
  codigo_externo text,
  prestador_id_1 text references public.hh_prestadores(id) on delete set null,
  rol_1 text default '',
  prestador_id_2 text references public.hh_prestadores(id) on delete set null,
  rol_2 text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.hh_modulos_asignados
  add column if not exists dupla_id text references public.hh_duplas(id) on delete set null;

do $$
declare
  t text;
  tables text[] := array['hh_duplas'];
begin
  foreach t in array tables loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I_select on public.%I', t, t);
    execute format('create policy %I_select on public.%I for select using (organization_id = public.current_org_id())', t, t);

    execute format('drop policy if exists %I_insert on public.%I', t, t);
    execute format('create policy %I_insert on public.%I for insert with check (organization_id = public.current_org_id())', t, t);

    execute format('drop policy if exists %I_update on public.%I', t, t);
    execute format('create policy %I_update on public.%I for update using (organization_id = public.current_org_id()) with check (organization_id = public.current_org_id())', t, t);

    execute format('drop policy if exists %I_delete on public.%I', t, t);
    execute format('create policy %I_delete on public.%I for delete using (organization_id = public.current_org_id())', t, t);
  end loop;
end $$;
