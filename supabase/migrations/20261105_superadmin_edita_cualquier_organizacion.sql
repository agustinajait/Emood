-- ============================================================
-- E-Mood — El superadmin puede editar el perfil público y la
-- documentación legal de CUALQUIER organización, no solo la que
-- tiene "parada" en este momento
-- ============================================================
-- org_select ya dejaba ver todas las organizaciones (is_superadmin()
-- agregado en 20260831_superadmin.sql), pero org_update seguía
-- exigiendo id = current_org_id() — así que desde "Organizaciones"
-- el superadmin podía ABRIR el perfil/documentación de otra
-- organización pero no guardar cambios ahí sin antes "entrar" a ella.
-- ============================================================

drop policy if exists org_update on public.organizations;
create policy org_update on public.organizations for update
  using (id = public.current_org_id() or public.is_superadmin())
  with check (id = public.current_org_id() or public.is_superadmin());
