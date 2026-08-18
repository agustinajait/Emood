-- ============================================================
-- E-Mood — Bucket de storage para evidencia de módulos
-- ============================================================

insert into storage.buckets (id, name, public)
values ('modulo-evidencias', 'modulo-evidencias', true)
on conflict (id) do nothing;

drop policy if exists "modulo-evidencias insert" on storage.objects;
create policy "modulo-evidencias insert" on storage.objects for insert to authenticated
with check (bucket_id = 'modulo-evidencias');

drop policy if exists "modulo-evidencias select" on storage.objects;
create policy "modulo-evidencias select" on storage.objects for select
using (bucket_id = 'modulo-evidencias');

drop policy if exists "modulo-evidencias update" on storage.objects;
create policy "modulo-evidencias update" on storage.objects for update to authenticated
using (bucket_id = 'modulo-evidencias');
