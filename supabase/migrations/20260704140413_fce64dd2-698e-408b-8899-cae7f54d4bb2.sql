
-- ============================================================
-- 1) FACTURES : statut auto (payee / partiellement_payee / impayee)
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_facture_statut_auto()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_paye numeric := COALESCE(NEW.montant_paye, 0);
  v_total numeric := COALESCE(NEW.montant_total, 0);
BEGIN
  -- On respecte les statuts sp\u00e9ciaux verrouill\u00e9s
  IF NEW.statut IN ('annulee', 'avoir') THEN
    RETURN NEW;
  END IF;

  IF v_total > 0 AND v_paye >= v_total THEN
    NEW.statut := 'payee';
  ELSIF v_paye > 0 AND v_paye < v_total THEN
    NEW.statut := 'partiellement_payee';
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

-- Rattrapage historique
UPDATE public.factures
SET montant_paye = montant_paye
WHERE statut NOT IN ('annulee', 'avoir');

-- ============================================================
-- 2) BONS DE LIVRAISON : passage auto en 'livre' quand tous les colis livr\u00e9s
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_bl_livre_when_all_colis_livres()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bl uuid := NEW.bl_id;
  v_total int;
  v_livres int;
BEGIN
  IF v_bl IS NULL THEN
    RETURN NEW;
  END IF;

  -- On ne d\u00e9clenche que quand un colis passe \u00e0 'livre'
  IF NEW.statut IS DISTINCT FROM 'livre' THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE statut = 'livre')
    INTO v_total, v_livres
    FROM public.colis
   WHERE bl_id = v_bl;

  IF v_total > 0 AND v_livres = v_total THEN
    UPDATE public.bons_livraison
       SET statut = 'livre',
           date_livraison = COALESCE(date_livraison, CURRENT_DATE)
     WHERE bl_id = v_bl
       AND statut IS DISTINCT FROM 'livre';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bl_livre_auto ON public.colis;
CREATE TRIGGER trg_bl_livre_auto
  AFTER INSERT OR UPDATE OF statut, bl_id
  ON public.colis
  FOR EACH ROW
  EXECUTE FUNCTION public.set_bl_livre_when_all_colis_livres();

REVOKE ALL ON FUNCTION public.set_bl_livre_when_all_colis_livres() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_facture_statut_auto() FROM PUBLIC, anon, authenticated;
