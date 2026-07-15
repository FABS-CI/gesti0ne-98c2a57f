-- ═══════════════════════════════════════════════════════════════════
-- Phase 2 — Étape C (retry) : migrer trg_notif_stock sur stocks_depots
-- puis DROP la colonne produits.stock.
-- ═══════════════════════════════════════════════════════════════════

-- 1) Nouveau trigger de notification basé sur stocks_depots
CREATE OR REPLACE FUNCTION public.trg_notif_stock_depots()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_produit_id uuid;
  v_titre text;
  v_ref text;
  v_seuil int;
  v_stock_old int;
  v_stock_new int;
BEGIN
  v_produit_id := COALESCE(NEW.produit_id, OLD.produit_id);

  SELECT titre, reference, COALESCE(seuil_alerte, 0)
    INTO v_titre, v_ref, v_seuil
    FROM public.produits WHERE produit_id = v_produit_id;
  IF v_titre IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;

  SELECT COALESCE(SUM(quantite),0)::int INTO v_stock_new
    FROM public.stocks_depots WHERE produit_id = v_produit_id;

  -- Stock avant : on soustrait le delta du dépôt concerné
  v_stock_old := v_stock_new
    - COALESCE(NEW.quantite, 0)
    + COALESCE(OLD.quantite, 0);

  IF v_stock_old IS NOT DISTINCT FROM v_stock_new THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF v_stock_new <= 0 AND v_stock_old > 0 THEN
    PERFORM public.creer_notification('Rupture de stock — '||v_titre,
      'Stock épuisé','erreur','stock','produits',v_produit_id,v_ref,
      '/stock','gestionnaire_stock',NULL,'critique');
    PERFORM public.creer_notification('Rupture de stock — '||v_titre,
      'Stock épuisé','erreur','stock','produits',v_produit_id,v_ref,
      '/stock','responsable_magasinier',NULL,'critique');
  ELSIF v_seuil > 0 AND v_stock_new <= v_seuil AND v_stock_old > v_seuil THEN
    PERFORM public.creer_notification('Stock faible — '||v_titre,
      'Stock '||v_stock_new||' ≤ seuil '||v_seuil,'alerte','stock','produits',v_produit_id,v_ref,
      '/stock','gestionnaire_stock',NULL,'haute');
  ELSIF v_stock_new > v_seuil AND v_stock_old <= v_seuil THEN
    PERFORM public.creer_notification('Réapprovisionnement — '||v_titre,
      'Stock revenu à '||v_stock_new,'succes','stock','produits',v_produit_id,v_ref,
      '/stock','gestionnaire_stock',NULL,'normale');
  END IF;

  RETURN COALESCE(NEW, OLD);
END $function$;

DROP TRIGGER IF EXISTS trg_notif_stock_on_depots ON public.stocks_depots;
CREATE TRIGGER trg_notif_stock_on_depots
  AFTER INSERT OR UPDATE OR DELETE ON public.stocks_depots
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_stock_depots();

-- 2) DROP des triggers qui référencent produits.stock
DROP TRIGGER IF EXISTS trg_notif_stock ON public.produits;
DROP FUNCTION IF EXISTS public.trg_notif_stock() CASCADE;

DROP TRIGGER IF EXISTS trg_produits_stock_readonly ON public.produits;
DROP FUNCTION IF EXISTS public.guard_produits_stock_readonly() CASCADE;

DROP TRIGGER IF EXISTS trg_block_produit_stock_write ON public.produits;
DROP FUNCTION IF EXISTS public.block_direct_produit_stock_write() CASCADE;

-- 3) Trigger de sync stocks_depots → produits.stock (Phase 1) : plus besoin
DROP TRIGGER IF EXISTS trg_sync_produit_stock ON public.stocks_depots;
DROP FUNCTION IF EXISTS public.sync_produit_stock_from_depots() CASCADE;

-- 4) Index technique sur la colonne qui va disparaître
DROP INDEX IF EXISTS public.idx_produits_actif_stock;

-- 5) DROP final de la colonne
ALTER TABLE public.produits DROP COLUMN IF EXISTS stock;

-- 6) Recréer v_produits (référence produits.* → besoin d'un CREATE OR REPLACE)
CREATE OR REPLACE VIEW public.v_produits WITH (security_invoker = true) AS
SELECT
  p.produit_id, p.reference, p.titre, p.isbn,
  p.categorie, p.categorie_id, p.niveau, p.niveau_ordre,
  p.matiere, p.auteur, p.editeur, p.prix_vente, p.prix_achat,
  COALESCE((
    SELECT SUM(sd.quantite)::int
    FROM public.stocks_depots sd
    WHERE sd.produit_id = p.produit_id
  ), 0) AS stock,
  p.seuil_alerte, p.actif, p.created_at, p.updated_at
FROM public.produits p;

GRANT SELECT ON public.v_produits TO authenticated, anon;

COMMENT ON VIEW public.v_produits IS
  'Vue de lecture officielle des produits. stock = SUM(stocks_depots.quantite) — source unique de vérité multi-dépôts (Phase 2 finalisée).';