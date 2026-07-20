
CREATE INDEX IF NOT EXISTS idx_clients_actif_created_at ON public.clients (actif, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clients_nom_asc ON public.clients (nom ASC);
CREATE INDEX IF NOT EXISTS idx_clients_nom_trgm ON public.clients USING gin (nom gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clients_reference_trgm ON public.clients USING gin (reference gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clients_representant_trgm ON public.clients USING gin (representant gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_factures_client_id ON public.factures (client_id) WHERE client_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_paiements_facture_id ON public.paiements (facture_id);
CREATE INDEX IF NOT EXISTS idx_retours_client_id ON public.retours (client_id) WHERE client_id IS NOT NULL;
