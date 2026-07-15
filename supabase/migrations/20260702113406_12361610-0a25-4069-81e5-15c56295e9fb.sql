
-- Trigger to force factures/bons_livraison/proformas.montant_total to always align with commandes.montant_total on insert or update.
CREATE OR REPLACE FUNCTION public.sync_doc_montant_from_commande()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total numeric;
BEGIN
  IF NEW.commande_id IS NOT NULL THEN
    SELECT montant_total INTO v_total FROM public.commandes WHERE commande_id = NEW.commande_id;
    IF v_total IS NOT NULL THEN
      NEW.montant_total := v_total;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_facture_montant ON public.factures;
CREATE TRIGGER trg_sync_facture_montant
BEFORE INSERT OR UPDATE OF commande_id, montant_total ON public.factures
FOR EACH ROW EXECUTE FUNCTION public.sync_doc_montant_from_commande();

DROP TRIGGER IF EXISTS trg_sync_bl_montant ON public.bons_livraison;
CREATE TRIGGER trg_sync_bl_montant
BEFORE INSERT OR UPDATE OF commande_id, montant_total ON public.bons_livraison
FOR EACH ROW EXECUTE FUNCTION public.sync_doc_montant_from_commande();

DROP TRIGGER IF EXISTS trg_sync_proforma_montant ON public.proformas;
CREATE TRIGGER trg_sync_proforma_montant
BEFORE INSERT OR UPDATE OF commande_id, montant_total ON public.proformas
FOR EACH ROW EXECUTE FUNCTION public.sync_doc_montant_from_commande();

-- One-time backfill to align existing documents with their commande total.
UPDATE public.factures f SET montant_total = c.montant_total
FROM public.commandes c
WHERE f.commande_id = c.commande_id AND f.montant_total IS DISTINCT FROM c.montant_total;

UPDATE public.bons_livraison b SET montant_total = c.montant_total
FROM public.commandes c
WHERE b.commande_id = c.commande_id AND b.montant_total IS DISTINCT FROM c.montant_total;

UPDATE public.proformas p SET montant_total = c.montant_total
FROM public.commandes c
WHERE p.commande_id = c.commande_id AND p.montant_total IS DISTINCT FROM c.montant_total;
