-- ============================================================
-- E-Mood — Tipo de contrato del prestador + documento adjunto
-- ============================================================

alter table if exists public.hh_prestadores
  add column if not exists tipo_contrato text,
  add column if not exists doc_contrato_url text;

-- Bucket de storage para los documentos de contrato (monotributo, etc.)
insert into storage.buckets (id, name, public)
values ('prestador-docs', 'prestador-docs', true)
on conflict (id) do nothing;

drop policy if exists "prestador-docs insert" on storage.objects;
create policy "prestador-docs insert" on storage.objects for insert to authenticated
with check (bucket_id = 'prestador-docs');

drop policy if exists "prestador-docs select" on storage.objects;
create policy "prestador-docs select" on storage.objects for select
using (bucket_id = 'prestador-docs');

drop policy if exists "prestador-docs update" on storage.objects;
create policy "prestador-docs update" on storage.objects for update to authenticated
using (bucket_id = 'prestador-docs');
