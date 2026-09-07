-- ============================================================
-- E-Mood — Perfil completo del prestador (requisito para postularse)
-- ============================================================
-- Al darse de alta, el prestador ahora completa su perfil (apellido,
-- dirección, teléfono, email y fecha de nacimiento) desde "Mis
-- datos". Con el perfil completo puede postularse a cualquier
-- módulo disponible de cualquier organización — antes solo hacía
-- falta el nombre.
-- ============================================================

alter table public.hh_prestadores
  add column if not exists apellido text default '',
  add column if not exists direccion text default '',
  add column if not exists telefono text default '',
  add column if not exists email text default '',
  add column if not exists fecha_nacimiento date;
