-- Lot 1 : Élargir la publication Realtime aux tables opérationnelles
-- pour synchro automatique multi-utilisateurs (listes ventes/stock/livraison).
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'commandes','factures','paiements','retours',
    'stock_mouvements','stocks_depots','produits',
    'livraisons','bons_livraison','colis','tournees','livsuivi_commandes',
    'clients','proformas'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
    -- REPLICA IDENTITY FULL pour que les événements UPDATE/DELETE incluent
    -- toutes les colonnes (nécessaire pour l'invalidation ciblée par ID).
    EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END $$;