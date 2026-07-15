-- Aggrégat serveur pour les facettes clients (villes, représentants, types)
-- Évite de charger 1000+ lignes clients à chaque ouverture d'un filtre CRM/Rapport.
CREATE OR REPLACE FUNCTION public.clients_facets()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'villes', COALESCE((SELECT jsonb_agg(v ORDER BY v) FROM (SELECT DISTINCT ville AS v FROM public.clients WHERE actif AND ville IS NOT NULL AND ville <> '') s), '[]'::jsonb),
    'representants', COALESCE((SELECT jsonb_agg(v ORDER BY v) FROM (SELECT DISTINCT representant AS v FROM public.clients WHERE actif AND representant IS NOT NULL AND representant <> '') s), '[]'::jsonb),
    'types', COALESCE((SELECT jsonb_agg(v ORDER BY v) FROM (SELECT DISTINCT type_client AS v FROM public.clients WHERE actif AND type_client IS NOT NULL AND type_client <> '') s), '[]'::jsonb)
  )
$$;

GRANT EXECUTE ON FUNCTION public.clients_facets() TO authenticated;

-- Index composite pour accélérer la liste clients (ORDER BY created_at DESC + filtre actif)
CREATE INDEX IF NOT EXISTS idx_clients_actif_created_at
  ON public.clients (actif, created_at DESC);