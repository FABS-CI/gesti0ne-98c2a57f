
CREATE OR REPLACE FUNCTION public.dashboard_client_stats()
RETURNS TABLE (total bigint, actifs bigint, solde_total numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    count(*)::bigint AS total,
    count(*) FILTER (WHERE actif)::bigint AS actifs,
    COALESCE(sum(solde), 0)::numeric AS solde_total
  FROM public.clients;
$$;

GRANT EXECUTE ON FUNCTION public.dashboard_client_stats() TO authenticated;

CREATE INDEX IF NOT EXISTS idx_clients_actif ON public.clients(actif);
CREATE INDEX IF NOT EXISTS idx_commandes_exercice_date ON public.commandes(exercice_id, date_commande DESC);
CREATE INDEX IF NOT EXISTS idx_factures_exercice_statut ON public.factures(exercice_id, statut);
CREATE INDEX IF NOT EXISTS idx_transactions_exercice_type ON public.transactions(exercice_id, type);
CREATE INDEX IF NOT EXISTS idx_produits_actif_stock ON public.produits(actif, stock);
CREATE INDEX IF NOT EXISTS idx_clients_nom_trgm ON public.clients USING gin (nom gin_trgm_ops);
