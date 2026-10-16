-- ============================================================
-- E-Mood — Perfil público de la organización (bio, logo, sitio web)
-- ============================================================
-- Para que el prestador vea quién publica cada módulo: nombre,
-- logo y una bio corta, además del sitio web si tienen. Lo edita
-- el admin desde "🏢 Perfil público" en su Dashboard. Es visible sin
-- login (misma política de RLS ya ampliada para la home pública) y
-- también para cualquier prestador logueado.
-- ============================================================

alter table public.organizations
  add column if not exists descripcion text default '',
  add column if not exists logo_url text default '',
  add column if not exists sitio_web text default '';

-- Bucket de logos: público para lectura (así se puede mostrar sin
-- sesión), solo un usuario autenticado puede subir/actualizar.
insert into storage.buckets (id, name, public)
values ('org-logos', 'org-logos', true)
on conflict (id) do nothing;

drop policy if exists "org-logos insert" on storage.objects;
create policy "org-logos insert" on storage.objects for insert to authenticated
with check (bucket_id = 'org-logos');

drop policy if exists "org-logos select" on storage.objects;
create policy "org-logos select" on storage.objects for select
using (bucket_id = 'org-logos');

drop policy if exists "org-logos update" on storage.objects;
create policy "org-logos update" on storage.objects for update to authenticated
using (bucket_id = 'org-logos');
