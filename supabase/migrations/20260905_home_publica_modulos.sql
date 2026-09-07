-- ============================================================
-- E-Mood — Home pública: cualquiera (sin sesión) puede ver los
-- módulos activos y el nombre de la organización que los ofrece,
-- para invitar a postularse desde la home sin necesidad de login.
-- ============================================================
-- Los módulos "activo" ya eran visibles para cualquier prestador
-- logueado de cualquier organización (marketplace) — esto solo
-- saca el requisito de estar logueado para ese mismo caso.
-- ============================================================

drop policy if exists hh_servicios_select on public.hh_servicios;
create policy hh_servicios_select on public.hh_servicios for select using (
  organization_id = public.current_org_id()
  or estado = 'activo'
);

drop policy if exists org_select on public.organizations;
create policy org_select on public.organizations for select using (
  id = public.current_org_id()
  or public.is_superadmin()
  or active = true
);
