
-- =========================================================
-- Lot 2 : synchronisation automatique du solde client
-- =========================================================
CREATE OR REPLACE FUNCTION public.tg_sync_client_solde()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client uuid;
  v_tot_fac numeric;
  v_tot_pay numeric;
BEGIN
  -- Déterminer le client impacté selon la table source
  IF TG_TABLE_NAME = 'factures' THEN
    v_client := COALESCE(NEW.client_id, OLD.client_id);
  ELSIF TG_TABLE_NAME = 'paiements' THEN
    SELECT f.client_id INTO v_client
    FROM public.factures f
    WHERE f.facture_id = COALESCE(NEW.facture_id, OLD.facture_id);
  END IF;

  IF v_client IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT COALESCE(SUM(montant_total),0), COALESCE(SUM(montant_paye),0)
    INTO v_tot_fac, v_tot_pay
    FROM public.factures
   WHERE client_id = v_client
     AND (statut IS NULL OR statut <> 'annulee');

  UPDATE public.clients
     SET solde = v_tot_fac - v_tot_pay,
         updated_at = now()
   WHERE client_id = v_client
     AND solde IS DISTINCT FROM (v_tot_fac - v_tot_pay);

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_client_solde_factures ON public.factures;
CREATE TRIGGER trg_sync_client_solde_factures
AFTER INSERT OR UPDATE OF montant_total, montant_paye, statut, client_id OR DELETE
ON public.factures
FOR EACH ROW EXECUTE FUNCTION public.tg_sync_client_solde();

DROP TRIGGER IF EXISTS trg_sync_client_solde_paiements ON public.paiements;
CREATE TRIGGER trg_sync_client_solde_paiements
AFTER INSERT OR UPDATE OR DELETE
ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.tg_sync_client_solde();

-- Backfill immédiat de tous les soldes clients
UPDATE public.clients c
   SET solde = COALESCE(agg.solde, 0),
       updated_at = now()
  FROM (
    SELECT f.client_id,
           COALESCE(SUM(f.montant_total),0) - COALESCE(SUM(f.montant_paye),0) AS solde
      FROM public.factures f
     WHERE f.statut IS NULL OR f.statut <> 'annulee'
     GROUP BY f.client_id
  ) agg
 WHERE agg.client_id = c.client_id
   AND c.solde IS DISTINCT FROM COALESCE(agg.solde, 0);

-- =========================================================
-- Lot 1 : révoquer EXECUTE aux rôles anon sur toutes les fonctions
--         `public` (aucune n'est censée être appelée sans auth).
--         Les rôles `authenticated` et `service_role` conservent l'accès.
-- =========================================================
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.prokind = 'f'
       AND has_function_privilege('anon', p.oid, 'EXECUTE')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM anon, PUBLIC', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

-- =========================================================
-- Lot 5 : index de performance
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_clients_actif_created_at
  ON public.clients (actif, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_factures_client_exercice
  ON public.factures (client_id, exercice_id);
CREATE INDEX IF NOT EXISTS idx_paiements_facture
  ON public.paiements (facture_id);
CREATE INDEX IF NOT EXISTS idx_commandes_client_exercice
  ON public.commandes (client_id, exercice_id);
CREATE INDEX IF NOT EXISTS idx_bons_livraison_client_exercice
  ON public.bons_livraison (client_id, exercice_id);
CREATE INDEX IF NOT EXISTS idx_avoirs_client_exercice
  ON public.avoirs (client_id, exercice_id);
CREATE INDEX IF NOT EXISTS idx_retours_client_exercice
  ON public.retours (client_id, exercice_id);
CREATE INDEX IF NOT EXISTS idx_proformas_client_exercice
  ON public.proformas (client_id, exercice_id);
