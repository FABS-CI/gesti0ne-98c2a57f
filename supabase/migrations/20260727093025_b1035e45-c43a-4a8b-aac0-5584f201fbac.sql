CREATE OR REPLACE FUNCTION public.dashboard_widgets_all()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'clients_total', (SELECT count(*) FROM public.clients),
    'produits_total', (SELECT count(*) FROM public.produits),
    'factures_mois', (SELECT count(*) FROM public.factures WHERE created_at >= date_trunc('month', now())),
    'ca_mois', (SELECT COALESCE(sum(montant), 0) FROM public.paiements
                 WHERE statut = 'valide' AND date_paiement >= date_trunc('month', now())::date),
    'bl_en_cours', (SELECT count(*) FROM public.bons_livraison WHERE statut IS DISTINCT FROM 'livre'),
    'stock_faible', (SELECT count(*) FROM public.produits WHERE stock <= 5),
    'commandes_ouvertes', (SELECT count(*) FROM public.commandes WHERE statut IN ('brouillon','confirmee')),
    'paiements_recus_mois', (SELECT COALESCE(sum(montant), 0) FROM public.paiements
                 WHERE created_at >= date_trunc('month', now()))
  );
$$;

REVOKE ALL ON FUNCTION public.dashboard_widgets_all() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.dashboard_widgets_all() TO authenticated;
GRANT EXECUTE ON FUNCTION public.dashboard_widgets_all() TO service_role;