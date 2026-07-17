DROP FUNCTION IF EXISTS public.get_lignes_retournables(uuid);

CREATE OR REPLACE FUNCTION public.get_lignes_retournables(_facture_id uuid)
RETURNS TABLE(
  produit_id uuid,
  reference_produit text,
  designation text,
  qte_vendue numeric,
  qte_deja_retournee numeric,
  qte_disponible numeric,
  prix_unitaire numeric,
  remise_pct numeric,
  total_ligne numeric
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  WITH f AS (
    SELECT commande_id FROM public.factures WHERE facture_id = _facture_id
  ),
  cl AS (
    SELECT cl.produit_id, cl.reference_produit, cl.designation,
           cl.quantite::numeric AS qte_vendue,
           cl.prix_unitaire::numeric AS prix_unitaire,
           COALESCE(cl.remise_pct,0)::numeric AS remise_pct,
           COALESCE(cl.total_ligne,0)::numeric AS total_ligne
    FROM public.commande_lignes cl
    JOIN f ON f.commande_id = cl.commande_id
    WHERE cl.produit_id IS NOT NULL
  ),
  rl AS (
    SELECT rl.produit_id, SUM(rl.quantite)::numeric AS qte_deja_retournee
    FROM public.retour_lignes rl
    JOIN public.retours r ON r.retour_id = rl.retour_id
    WHERE r.facture_id = _facture_id
      AND r.statut <> 'annule'
    GROUP BY rl.produit_id
  )
  SELECT cl.produit_id, cl.reference_produit, cl.designation,
         cl.qte_vendue,
         COALESCE(rl.qte_deja_retournee,0) AS qte_deja_retournee,
         GREATEST(cl.qte_vendue - COALESCE(rl.qte_deja_retournee,0), 0) AS qte_disponible,
         cl.prix_unitaire, cl.remise_pct, cl.total_ligne
  FROM cl
  LEFT JOIN rl ON rl.produit_id = cl.produit_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_lignes_retournables(uuid) TO authenticated;