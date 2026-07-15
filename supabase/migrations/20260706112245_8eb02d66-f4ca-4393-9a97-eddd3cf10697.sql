
CREATE INDEX IF NOT EXISTS idx_livraisons_gare_depart ON public.livraisons(gare_depart_id);
CREATE INDEX IF NOT EXISTS idx_livraisons_gare_arrivee ON public.livraisons(gare_arrivee_id);

-- Recherche typeahead : trigram + filtre actif
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_transporteurs_nom_trgm
  ON public.transporteurs USING gin (nom gin_trgm_ops) WHERE actif = true;
CREATE INDEX IF NOT EXISTS idx_gares_nom_trgm
  ON public.gares USING gin (nom gin_trgm_ops) WHERE actif = true;
CREATE INDEX IF NOT EXISTS idx_livreurs_nom_trgm
  ON public.livreurs USING gin (nom gin_trgm_ops) WHERE actif = true;
