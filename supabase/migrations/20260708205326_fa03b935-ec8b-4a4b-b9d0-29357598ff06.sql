-- Phase 1: v_produits as read-source-of-truth for stock
CREATE OR REPLACE VIEW public.v_produits WITH (security_invoker = true) AS
SELECT
  p.produit_id,
  p.reference,
  p.titre,
  p.isbn,
  p.categorie,
  p.categorie_id,
  p.niveau,
  p.niveau_ordre,
  p.matiere,
  p.auteur,
  p.editeur,
  p.prix_vente,
  p.prix_achat,
  COALESCE((
    SELECT SUM(sd.quantite)::int
    FROM public.stocks_depots sd
    WHERE sd.produit_id = p.produit_id
  ), 0) AS stock,
  p.seuil_alerte,
  p.actif,
  p.created_at,
  p.updated_at
FROM public.produits p;

GRANT SELECT ON public.v_produits TO authenticated, anon;

-- Bloquer les écritures directes sur produits.stock depuis le front (PostgREST)
CREATE OR REPLACE FUNCTION public.block_direct_produit_stock_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Autorise les écritures internes (SECURITY DEFINER, service_role, postgres)
  -- Bloque uniquement les writes venant des rôles clients Data API
  IF NEW.stock IS DISTINCT FROM OLD.stock
     AND current_user IN ('authenticated', 'anon') THEN
    RAISE EXCEPTION
      'Écriture directe interdite sur produits.stock. Le stock est calculé depuis stocks_depots.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_produit_stock_write ON public.produits;
CREATE TRIGGER trg_block_produit_stock_write
  BEFORE UPDATE OF stock ON public.produits
  FOR EACH ROW
  EXECUTE FUNCTION public.block_direct_produit_stock_write();

COMMENT ON VIEW public.v_produits IS
  'Vue de lecture officielle des produits. Le champ stock est calculé à la volée depuis stocks_depots (source unique de vérité multi-dépôts).';