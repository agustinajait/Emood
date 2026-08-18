-- ============================================================
-- E-Mood — Flujo Servicio → Postulación → Módulo asignado → Remito
-- ============================================================
-- ORG crea Servicio
--   → prestador carga sus datos y aplica (Postulación)
--   → org acepta → se crea Módulo asignado (copia el protocolo del Servicio)
--   → prestador sube evidencia por cada ítem del protocolo
--   → org aprueba/rechaza cada ítem
--   → cuando todos los ítems están aprobados → módulo = 'completado'
--   → org genera Remito → módulo = 'aprobado'
-- ============================================================

begin;

-- ── Servicios (lo que la organización publica) ─────────────
create table if not exists public.hh_servicios (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  titulo text not null,
  descripcion text default '',
  frecuencia text not null default 'mensual' check (frecuencia in ('diaria','semanal','mensual','unica')),
  horas_modulo numeric not null default 0,
  precio_hora numeric not null default 0,
  deadline date,
  protocolo text not null default '[]',       -- JSON.stringify [{item, descripcion}]
  capacitacion_id text,                        -- texto libre por ahora (no hay tabla de capacitaciones todavía)
  docs_requeridos text not null default '[]',  -- JSON.stringify ["DNI","CUIL",...]
  estado text not null default 'activo' check (estado in ('activo','cerrado')),
  created_at timestamptz not null default now()
);

-- ── Postulaciones (prestador aplica a un Servicio) ──────────
create table if not exists public.hh_postulaciones (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  servicio_id text not null references public.hh_servicios(id) on delete cascade,
  prestador_id text not null references public.hh_prestadores(id) on delete cascade,
  mensaje text default '',
  docs_confirmados text not null default '[]', -- JSON.stringify de los docs que el prestador marcó como presentados
  estado text not null default 'pendiente' check (estado in ('pendiente','aceptada','rechazada')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (servicio_id, prestador_id)
);

-- ── Módulos asignados (instancia real de trabajo, nace al aceptar
--    una postulación; el protocolo se copia tal cual estaba en el
--    Servicio en ese momento) ─────────────────────────────────
create table if not exists public.hh_modulos_asignados (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  servicio_id text not null references public.hh_servicios(id) on delete cascade,
  postulacion_id text references public.hh_postulaciones(id) on delete set null,
  prestador_id text not null references public.hh_prestadores(id) on delete cascade,
  protocolo text not null default '[]', -- snapshot JSON del protocolo al momento de asignar
  estado text not null default 'en_progreso' check (estado in ('en_progreso','completado','aprobado')),
  remito_numero text,
  remito_fecha timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── Ítems del módulo asignado (uno por ítem del protocolo;
--    evidencia y aprobación van por ítem) ───────────────────
create table if not exists public.hh_modulo_items (
  id text primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  modulo_asignado_id text not null references public.hh_modulos_asignados(id) on delete cascade,
  item text not null,
  descripcion text default '',
  evidencia_url text default '',
  evidencia_nota text default '',
  estado text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  comentario_org text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── RLS: mismo patrón que el resto (acotado a organization_id) ─
do $$
declare
  t text;
  tables text[] := array['hh_servicios','hh_postulaciones','hh_modulos_asignados','hh_modulo_items'];
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

commit;
