
DROP VIEW IF EXISTS public.v_produits;

CREATE VIEW public.v_produits
WITH (security_invoker = on) AS
SELECT p.produit_id,
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
       COALESCE((SELECT SUM(sd.quantite)::int FROM public.stocks_depots sd WHERE sd.produit_id = p.produit_id), 0) AS stock
  FROM public.produits p;

GRANT SELECT ON public.v_produits TO authenticated;
GRANT ALL ON public.v_produits TO service_role;
