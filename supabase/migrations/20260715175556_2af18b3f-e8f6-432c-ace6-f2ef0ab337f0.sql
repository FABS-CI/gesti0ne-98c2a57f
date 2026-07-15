
CREATE OR REPLACE VIEW public.v_produits
WITH (security_invoker=on) AS
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
  p.seuil_alerte,
  p.pin_order,
  p.cover_path,
  p.cover_thumb_path,
  p.cover_updated_at,
  p.actif,
  p.created_at,
  p.updated_at,
  0::integer AS stock
FROM public.produits p;

GRANT SELECT ON public.v_produits TO authenticated;
GRANT SELECT ON public.v_produits TO service_role;
