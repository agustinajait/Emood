-- ============================================================
-- E-Mood — Arreglo: el prestador no podía crear los ítems del
-- ciclo cuando abre un mes nuevo desde su propio panel.
-- ============================================================
-- La política de INSERT de hh_modulo_items nunca se actualizó al
-- introducir los ciclos mensuales — seguía exigiendo que quien
-- inserta sea la organización dueña (organization_id = current_org_id()),
-- lo cual es imposible para un prestador (no tiene organización propia).
-- Como hh_modulo_ciclos_insert sí se corrigió, el ciclo se creaba
-- pero sus ítems no, dejando el ciclo vacío.
-- ============================================================

begin;

drop policy if exists hh_modulo_items_insert on public.hh_modulo_items;
create policy hh_modulo_items_insert on public.hh_modulo_items for insert with check (
  organization_id = public.current_org_id()
  or exists (select 1 from public.hh_modulos_asignados ma where ma.id = hh_modulo_items.modulo_asignado_id and ma.prestador_id = public.my_prestador_id())
);

commit;
