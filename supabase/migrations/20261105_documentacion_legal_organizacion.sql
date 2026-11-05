-- ============================================================
-- E-Mood — Documentación legal/institucional de la organización
-- ============================================================
-- Perfil de la organización que se va "constituyendo de a poco",
-- separado del perfil público (bio/logo/portada): son archivos de
-- uso interno para habilitación/compliance, no se muestran en la
-- página pública de la organización.
-- ============================================================

alter table if exists public.organizations
  add column if not exists doc_constancia_arca_url text,
  add column if not exists doc_dni_titular_url text,
  add column if not exists doc_cuit_representante_url text,
  add column if not exists doc_inscripcion_cioba_url text,
  add column if not exists doc_inscripcion_registro_ong_url text,
  add column if not exists doc_anexo_i_url text,
  add column if not exists doc_acta_constitutiva_url text,
  add column if not exists doc_estatuto_vigente_url text,
  add column if not exists doc_personeria_juridica_url text,
  add column if not exists doc_acta_designacion_autoridades_url text,
  add column if not exists doc_certificado_exencion_ganancias_url text,
  add column if not exists doc_situacion_juridica_inmueble_url text,
  add column if not exists doc_poliza_seguro_url text;

-- Bucket aparte para esta documentación (igual patrón que
-- prestador-docs: público para que cualquiera con el link pueda
-- verlo, inserción solo para usuarios autenticados).
insert into storage.buckets (id, name, public)
values ('org-docs', 'org-docs', true)
on conflict (id) do nothing;

drop policy if exists "org-docs insert" on storage.objects;
create policy "org-docs insert" on storage.objects for insert to authenticated
with check (bucket_id = 'org-docs');

drop policy if exists "org-docs select" on storage.objects;
create policy "org-docs select" on storage.objects for select
using (bucket_id = 'org-docs');

drop policy if exists "org-docs update" on storage.objects;
create policy "org-docs update" on storage.objects for update to authenticated
using (bucket_id = 'org-docs');
