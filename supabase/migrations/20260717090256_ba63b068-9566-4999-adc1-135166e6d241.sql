
-- 1) Corriger le default de paiements.statut
ALTER TABLE public.paiements ALTER COLUMN statut SET DEFAULT 'en_attente_validation';

-- 2) Trigger de défense en profondeur pour paiements
CREATE OR REPLACE FUNCTION public.paiements_enforce_validation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.statut IS NULL OR NEW.statut NOT IN ('en_attente_validation','valide','annule','rejete') THEN
    NEW.statut := 'en_attente_validation';
  END IF;
  -- Si l'appelant n'a pas la permission de valider, forcer en_attente
  IF NEW.statut = 'valide' AND auth.uid() IS NOT NULL
     AND NOT public.has_permission_v2(auth.uid(), 'paiements.valider') THEN
    NEW.statut := 'en_attente_validation';
    NEW.valide_par := NULL;
    NEW.valide_le := NULL;
  END IF;
  IF NEW.cree_par IS NULL THEN
    NEW.cree_par := auth.uid();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_paiements_enforce_validation ON public.paiements;
CREATE TRIGGER trg_paiements_enforce_validation
BEFORE INSERT ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.paiements_enforce_validation();

-- 3) Colonnes d'audit manquantes sur commandes
ALTER TABLE public.commandes
  ADD COLUMN IF NOT EXISTS valide_par uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS valide_le timestamptz,
  ADD COLUMN IF NOT EXISTS rejete_par uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS rejete_le timestamptz,
  ADD COLUMN IF NOT EXISTS motif_rejet text,
  ADD COLUMN IF NOT EXISTS commentaire_validation text;
