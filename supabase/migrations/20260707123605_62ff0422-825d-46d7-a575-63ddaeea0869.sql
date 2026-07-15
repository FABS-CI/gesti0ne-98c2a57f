-- Ajouter les colonnes de suivi de clôture (manuelle vs auto)
ALTER TABLE public.tournees
  ADD COLUMN IF NOT EXISTS cloture_mode text NULL,
  ADD COLUMN IF NOT EXISTS cloture_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS cloture_by uuid NULL;

ALTER TABLE public.tournees
  DROP CONSTRAINT IF EXISTS tournees_cloture_mode_check;
ALTER TABLE public.tournees
  ADD CONSTRAINT tournees_cloture_mode_check
  CHECK (cloture_mode IS NULL OR cloture_mode IN ('manuelle', 'auto'));

-- Mise à jour du trigger d'auto-clôture pour renseigner le mode + date
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
    SET statut = 'terminee',
        cloture_mode = COALESCE(cloture_mode, 'auto'),
        cloture_at = COALESCE(cloture_at, now())
    WHERE tournee_id = v_tournee_id
      AND statut NOT IN ('terminee', 'annulee');
  END IF;

  RETURN NEW;
END;
$$;