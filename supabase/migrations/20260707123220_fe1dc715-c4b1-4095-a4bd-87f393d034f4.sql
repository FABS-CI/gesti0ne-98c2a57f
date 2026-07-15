-- Colonne d'affectation manuelle des colis à une tournée
ALTER TABLE public.colis
  ADD COLUMN IF NOT EXISTS tournee_id uuid NULL
  REFERENCES public.tournees(tournee_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_colis_tournee_id
  ON public.colis(tournee_id)
  WHERE tournee_id IS NOT NULL;

-- Auto-clôture de la tournée quand tous les colis sont livrés
CREATE OR REPLACE FUNCTION public.trg_tournee_auto_terminee()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournee_id uuid;
  v_total int;
  v_livres int;
  v_statut text;
BEGIN
  v_tournee_id := COALESCE(NEW.tournee_id, OLD.tournee_id);
  IF v_tournee_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT statut INTO v_statut FROM public.tournees WHERE tournee_id = v_tournee_id;
  IF v_statut IS NULL OR v_statut IN ('terminee', 'annulee') THEN
    RETURN NEW;
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE statut_logistique = 'livre' OR date_livraison_reelle IS NOT NULL)
  INTO v_total, v_livres
  FROM public.colis
  WHERE tournee_id = v_tournee_id;

  IF v_total > 0 AND v_total = v_livres THEN
    UPDATE public.tournees
    SET statut = 'terminee'
    WHERE tournee_id = v_tournee_id
      AND statut NOT IN ('terminee', 'annulee');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tournee_auto_terminee_colis ON public.colis;
CREATE TRIGGER trg_tournee_auto_terminee_colis
AFTER UPDATE OF statut_logistique, date_livraison_reelle, tournee_id
ON public.colis
FOR EACH ROW
EXECUTE FUNCTION public.trg_tournee_auto_terminee();