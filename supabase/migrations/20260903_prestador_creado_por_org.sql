-- ============================================================
-- E-Mood — Un prestador queda visible para la organización que lo
-- dio de alta, sin depender de que ya tenga postulación, módulo
-- asignado o dupla.
-- ============================================================
-- hh_prestadores_select solo daba visibilidad vía postulación,
-- módulo asignado o (el intento anterior) dupla — pero "Importar
-- duplas" a veces no llega a crear la dupla (falta el código, no
-- son exactamente 2 personas, etc.), y aun así el prestador SÍ se
-- crea. Resultado: quedaba invisible para su propia organización,
-- sin ningún enganche posible. Se arregla con una columna que
-- registra quién lo dio de alta, en vez de inferirlo de otra tabla.
-- ============================================================

alter table public.hh_prestadores
  add column if not exists created_by_org_id uuid references public.organizations(id);

-- Backfill puntual: los 25 prestadores importados el 04/09 quedan
-- atados a Caii (la organización que los cargó), para que vuelvan
-- a aparecer sin tener que reimportar nada.
update public.hh_prestadores
set created_by_org_id = 'a9995322-b033-4469-8f05-c7c057a539ce'
where created_at >= '2026-09-04 19:17:00+00' and created_at <= '2026-09-04 19:19:00+00'
  and created_by_org_id is null;

drop policy if exists hh_prestadores_select on public.hh_prestadores;
create policy hh_prestadores_select on public.hh_prestadores for select using (
  id = public.my_prestador_id()
  or created_by_org_id = public.current_org_id()
  or exists (select 1 from public.hh_postulaciones po where po.prestador_id = hh_prestadores.id and po.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_modulos_asignados ma where ma.prestador_id = hh_prestadores.id and ma.organization_id = public.current_org_id())
  or exists (select 1 from public.hh_duplas d where (d.prestador_id_1 = hh_prestadores.id or d.prestador_id_2 = hh_prestadores.id) and d.organization_id = public.current_org_id())
);
