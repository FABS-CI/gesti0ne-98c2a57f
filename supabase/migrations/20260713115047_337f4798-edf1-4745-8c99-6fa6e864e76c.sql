-- ============================================================
-- Guards de transition de statut (BLOC 2B)
-- Chaque table a une fonction dédiée qui rejette les transitions
-- hors matrice validée. Les no-op (même statut) sont autorisés.
-- ============================================================

-- Helper : lève une erreur normalisée
CREATE OR REPLACE FUNCTION public._raise_bad_transition(_table text, _old text, _new text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Transition de statut interdite sur %: % → %', _table, COALESCE(_old,'∅'), COALESCE(_new,'∅')
    USING ERRCODE = 'check_violation';
END;
$$;

-- ---------- COMMANDES ----------
CREATE OR REPLACE FUNCTION public.trg_guard_statut_commandes()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;
  IF NEW.statut = 'annulee' AND OLD.statut <> 'cloturee' THEN RETURN NEW; END IF;
  IF (OLD.statut = 'brouillon'  AND NEW.statut = 'validee')
  OR (OLD.statut = 'validee'    AND NEW.statut = 'livree')
  OR (OLD.statut = 'livree'     AND NEW.statut = 'cloturee') THEN
    RETURN NEW;
  END IF;
  PERFORM public._raise_bad_transition('commandes', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_guard_statut_commandes ON public.commandes;
CREATE TRIGGER trg_guard_statut_commandes BEFORE UPDATE OF statut ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.trg_guard_statut_commandes();

-- ---------- FACTURES ----------
CREATE OR REPLACE FUNCTION public.trg_guard_statut_factures()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;
  IF (OLD.statut = 'brouillon' AND NEW.statut = 'emise')
  OR (OLD.statut = 'emise'     AND NEW.statut IN ('payee','annulee')) THEN
    RETURN NEW;
  END IF;
  PERFORM public._raise_bad_transition('factures', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_guard_statut_factures ON public.factures;
CREATE TRIGGER trg_guard_statut_factures BEFORE UPDATE OF statut ON public.factures
  FOR EACH ROW EXECUTE FUNCTION public.trg_guard_statut_factures();

-- ---------- PROFORMAS ----------
CREATE OR REPLACE FUNCTION public.trg_guard_statut_proformas()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;
  IF (OLD.statut = 'brouillon'  AND NEW.statut = 'en_attente')
  OR (OLD.statut = 'en_attente' AND NEW.statut IN ('acceptee','refusee','expiree'))
  OR (OLD.statut = 'acceptee'   AND NEW.statut = 'convertie') THEN
    RETURN NEW;
  END IF;
  PERFORM public._raise_bad_transition('proformas', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_guard_statut_proformas ON public.proformas;
CREATE TRIGGER trg_guard_statut_proformas BEFORE UPDATE OF statut ON public.proformas
  FOR EACH ROW EXECUTE FUNCTION public.trg_guard_statut_proformas();

-- ---------- BONS_LIVRAISON ----------
CREATE OR REPLACE FUNCTION public.trg_guard_statut_bons_livraison()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;
  IF NEW.statut = 'annule' AND OLD.statut <> 'livre' THEN RETURN NEW; END IF;
  IF (OLD.statut = 'en_preparation'   AND NEW.statut = 'colisage_termine')
  OR (OLD.statut = 'colisage_termine' AND NEW.statut = 'expedie')
  OR (OLD.statut = 'expedie'          AND NEW.statut = 'livre') THEN
    RETURN NEW;
  END IF;
  PERFORM public._raise_bad_transition('bons_livraison', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_guard_statut_bons_livraison ON public.bons_livraison;
CREATE TRIGGER trg_guard_statut_bons_livraison BEFORE UPDATE OF statut ON public.bons_livraison
  FOR EACH ROW EXECUTE FUNCTION public.trg_guard_statut_bons_livraison();

-- ---------- RETOURS ----------
CREATE OR REPLACE FUNCTION public.trg_guard_statut_retours()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;
  IF NEW.statut = 'annule' AND OLD.statut IN ('brouillon','valide') THEN RETURN NEW; END IF;
  IF (OLD.statut = 'brouillon' AND NEW.statut = 'valide')
  OR (OLD.statut = 'valide'    AND NEW.statut = 'traite')
  OR (OLD.statut = 'traite'    AND NEW.statut = 'cloture') THEN
    RETURN NEW;
  END IF;
  PERFORM public._raise_bad_transition('retours', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_guard_statut_retours ON public.retours;
CREATE TRIGGER trg_guard_statut_retours BEFORE UPDATE OF statut ON public.retours
  FOR EACH ROW EXECUTE FUNCTION public.trg_guard_statut_retours();

-- ---------- AVOIRS ----------
CREATE OR REPLACE FUNCTION public.trg_guard_statut_avoirs()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;
  IF (OLD.statut = 'brouillon' AND NEW.statut = 'emis')
  OR (OLD.statut = 'emis'      AND NEW.statut IN ('applique','annule')) THEN
    RETURN NEW;
  END IF;
  PERFORM public._raise_bad_transition('avoirs', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_guard_statut_avoirs ON public.avoirs;
CREATE TRIGGER trg_guard_statut_avoirs BEFORE UPDATE OF statut ON public.avoirs
  FOR EACH ROW EXECUTE FUNCTION public.trg_guard_statut_avoirs();

-- ---------- EXPEDITIONS ----------
CREATE OR REPLACE FUNCTION public.trg_guard_statut_expeditions()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;
  IF NEW.statut = 'annulee' AND OLD.statut <> 'livree' THEN RETURN NEW; END IF;
  IF (OLD.statut = 'preparee' AND NEW.statut = 'en_cours')
  OR (OLD.statut = 'en_cours' AND NEW.statut = 'livree') THEN
    RETURN NEW;
  END IF;
  PERFORM public._raise_bad_transition('expeditions', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_guard_statut_expeditions ON public.expeditions;
CREATE TRIGGER trg_guard_statut_expeditions BEFORE UPDATE OF statut ON public.expeditions
  FOR EACH ROW EXECUTE FUNCTION public.trg_guard_statut_expeditions();

-- ---------- ACHATS ----------
CREATE OR REPLACE FUNCTION public.trg_guard_statut_achats()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut IS NOT DISTINCT FROM OLD.statut THEN RETURN NEW; END IF;
  IF NEW.statut = 'annulee' AND OLD.statut <> 'cloturee' THEN RETURN NEW; END IF;
  IF (OLD.statut = 'brouillon'    AND NEW.statut = 'confirmee')
  OR (OLD.statut = 'confirmee'    AND NEW.statut = 'receptionnee')
  OR (OLD.statut = 'receptionnee' AND NEW.statut = 'cloturee') THEN
    RETURN NEW;
  END IF;
  PERFORM public._raise_bad_transition('achats', OLD.statut, NEW.statut);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_guard_statut_achats ON public.achats;
CREATE TRIGGER trg_guard_statut_achats BEFORE UPDATE OF statut ON public.achats
  FOR EACH ROW EXECUTE FUNCTION public.trg_guard_statut_achats();