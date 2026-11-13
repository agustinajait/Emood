-- ============================================================
-- E-Mood — foto ilustrativa general de cada módulo/servicio
-- ============================================================
-- El admin puede subir una foto que ilustra la actividad del
-- módulo (se muestra en la home, en el detalle público y en el
-- listado de "Módulos" del panel). Es opcional. Se guarda en el
-- bucket "modulo-docs" que ya existe (mismo bucket que el
-- documento adjunto del módulo, con otro prefijo de archivo), así
-- que no hace falta crear un bucket ni políticas nuevas.
-- ============================================================

alter table public.hh_servicios add column if not exists foto_url text not null default '';
