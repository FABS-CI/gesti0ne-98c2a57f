CREATE OR REPLACE FUNCTION public._retour_recalc_totaux(p_retour_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.retours r SET
    nb_produits    = agg.nb,
    total_quantite = agg.qte,
    montant        = agg.montant,
    updated_at     = now()
  FROM (
    SELECT COUNT(*)::int AS nb,
           COALESCE(SUM(COALESCE(quantite_recue, quantite, 0)),0) AS qte,
           COALESCE(SUM(total_ligne),0) AS montant
    FROM public.retour_lignes WHERE retour_id = p_retour_id
  ) agg
  WHERE r.retour_id = p_retour_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public._retour_recalc_totaux(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._retour_recalc_totaux(uuid) TO service_role;