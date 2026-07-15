
-- Normaliser les valeurs historiques vers le vocabulaire de l'UI
UPDATE public.factures
   SET statut = 'partielle'
 WHERE statut = 'partiellement_payee';

-- Reprise du trigger avec les bonnes valeurs
CREATE OR REPLACE FUNCTION public.set_facture_statut_auto()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_paye  numeric := COALESCE(NEW.montant_paye, 0);
  v_total numeric := COALESCE(NEW.montant_total, 0);
BEGIN
  -- Statuts figés : non recalculés
  IF NEW.statut IN ('annulee', 'avoir') THEN
    RETURN NEW;
  END IF;

  IF v_total > 0 AND v_paye >= v_total THEN
    NEW.statut := 'payee';
  ELSIF v_paye > 0 AND v_paye < v_total THEN
    NEW.statut := 'partielle';
  ELSE
    NEW.statut := 'impayee';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_facture_statut_auto ON public.factures;
CREATE TRIGGER trg_facture_statut_auto
  BEFORE INSERT OR UPDATE OF montant_total, montant_paye, statut
  ON public.factures
  FOR EACH ROW
  EXECUTE FUNCTION public.set_facture_statut_auto();

REVOKE ALL ON FUNCTION public.set_facture_statut_auto() FROM PUBLIC, anon, authenticated;

-- Rattrapage historique complet : recalcul en dur sur toutes les factures actives
UPDATE public.factures
   SET statut = CASE
     WHEN COALESCE(montant_total, 0) > 0
          AND COALESCE(montant_paye, 0) >= COALESCE(montant_total, 0) THEN 'payee'
     WHEN COALESCE(montant_paye, 0) > 0
          AND COALESCE(montant_paye, 0) < COALESCE(montant_total, 0) THEN 'partielle'
     ELSE 'impayee'
   END
 WHERE statut NOT IN ('annulee', 'avoir');
