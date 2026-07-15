CREATE OR REPLACE FUNCTION public.trg_guard_statut_commandes()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;
  IF NEW.statut = 'annulee' AND OLD.statut <> 'cloturee' THEN RETURN NEW; END IF;
  IF (OLD.statut = 'brouillon'            AND NEW.statut IN ('en_attente_validation','validee'))
  OR (OLD.statut = 'en_attente_validation' AND NEW.statut IN ('validee','brouillon'))
  OR (OLD.statut = 'validee'              AND NEW.statut IN ('facturee','livree'))
  OR (OLD.statut = 'facturee'             AND NEW.statut = 'livree')
  OR (OLD.statut = 'livree'               AND NEW.statut = 'cloturee') THEN
    RETURN NEW;
  END IF;
  PERFORM public._raise_bad_transition('commandes', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;