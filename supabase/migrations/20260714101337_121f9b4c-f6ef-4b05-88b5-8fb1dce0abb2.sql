
CREATE OR REPLACE FUNCTION public.trg_guard_statut_factures()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;

  -- Annulation / avoir autorisés depuis tout statut actif
  IF NEW.statut IN ('annulee','avoir')
     AND OLD.statut IN ('impayee','partielle','payee') THEN
    RETURN NEW;
  END IF;

  -- Transitions liées aux paiements (progression ou annulation d'un règlement)
  IF (OLD.statut = 'impayee'   AND NEW.statut IN ('partielle','payee'))
  OR (OLD.statut = 'partielle' AND NEW.statut IN ('impayee','payee'))
  OR (OLD.statut = 'payee'     AND NEW.statut IN ('partielle','impayee')) THEN
    RETURN NEW;
  END IF;

  PERFORM public._raise_bad_transition('factures', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;
