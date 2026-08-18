-- ============================================================
-- E-Mood — Tipo de contrato del módulo (Servicio) + documento
-- ============================================================
-- Va en la descripción del módulo, no en el prestador: la
-- organización indica bajo qué figura se contrata ese servicio
-- (Monotributo, etc.) y puede adjuntar un documento de referencia.
-- ============================================================

alter table if exists public.hh_servicios
  add column if not exists tipo_contrato text,
  add column if not exists doc_adjunto_url text;

-- Bucket de storage para los documentos adjuntos al módulo
insert into storage.buckets (id, name, public)
values ('modulo-docs', 'modulo-docs', true)
on conflict (id) do nothing;

drop policy if exists "modulo-docs insert" on storage.objects;
create policy "modulo-docs insert" on storage.objects for insert to authenticated
with check (bucket_id = 'modulo-docs');

drop policy if exists "modulo-docs select" on storage.objects;
create policy "modulo-docs select" on storage.objects for select
using (bucket_id = 'modulo-docs');

drop policy if exists "modulo-docs update" on storage.objects;
create policy "modulo-docs update" on storage.objects for update to authenticated
using (bucket_id = 'modulo-docs');
