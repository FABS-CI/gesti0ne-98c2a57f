CREATE OR REPLACE VIEW public.v_produits AS
SELECT
  produit_id,
  reference,
  titre,
  isbn,
  categorie,
  categorie_id,
  niveau,
  niveau_ordre,
  matiere,
  auteur,
  editeur,
  prix_vente,
  prix_achat,
  COALESCE((SELECT sum(sd.quantite)::integer FROM stocks_depots sd WHERE sd.produit_id = p.produit_id), 0) AS stock,
  seuil_alerte,
  actif,
  created_at,
  updated_at,
  CASE WHEN produit_id = 'f8572bf4-4da3-430f-874f-98972a1f9d17'::uuid THEN 0 ELSE 1 END AS pin_order
FROM produits p;

GRANT SELECT ON public.v_produits TO anon, authenticated;