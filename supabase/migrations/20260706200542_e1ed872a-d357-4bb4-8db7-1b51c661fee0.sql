-- 1) Fonction de mapping enrichie (Maternelle/BEPC/BAC/Littérature)
CREATE OR REPLACE FUNCTION public.produit_niveau_ordre(n text)
RETURNS int
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN n IS NULL OR n = '' THEN 9999
    -- Ordre : chercher d'abord les niveaux les plus précis
    WHEN n ~* 'cp\s*1' THEN 40
    WHEN n ~* 'cp\s*2' THEN 50
    WHEN n ~* 'ce\s*1' THEN 60
    WHEN n ~* 'ce\s*2' THEN 70
    WHEN n ~* 'cm\s*1' THEN 80
    WHEN n ~* 'cm\s*2' THEN 90
    WHEN n ~* '(^|[^0-9])6\s*[èei]?[èe]?me' OR n ~* '(^|[^a-z0-9])6e([^a-z]|$)' THEN 100
    WHEN n ~* '(^|[^0-9])5\s*[èei]?[èe]?me' OR n ~* '(^|[^a-z0-9])5e([^a-z]|$)' THEN 110
    WHEN n ~* '(^|[^0-9])4\s*[èei]?[èe]?me' OR n ~* '(^|[^a-z0-9])4e([^a-z]|$)' THEN 120
    WHEN n ~* '(^|[^0-9])3\s*[èei]?[èe]?me' OR n ~* '(^|[^a-z0-9])3e([^a-z]|$)' THEN 130
    WHEN n ILIKE '%seconde%' OR n ~* '(^|[^a-z])2nde([^a-z]|$)' THEN 140
    WHEN n ILIKE '%premi%re%' OR n ~* '(^|[^a-z])1[èe]re([^a-z]|$)' OR n ~* '(^|[^a-z])1ere([^a-z]|$)' THEN 150
    WHEN n ILIKE '%terminale%' OR n ~* '(^|[^a-z])(tle|term)([^a-z]|$)' THEN 160
    WHEN n ~* 'cepe' THEN 95
    WHEN n ~* 'bepc' THEN 170
    WHEN n ~* '(^|[^a-z])bac([^a-z]|$)' THEN 180
    WHEN n ILIKE '%maternelle%' THEN 5
    WHEN n ILIKE '%petite section%' OR n ~* '(^|[^a-z])ps([^a-z]|$)' THEN 10
    WHEN n ILIKE '%moyenne section%' OR n ~* '(^|[^a-z])ms([^a-z]|$)' THEN 20
    WHEN n ILIKE '%grande section%' OR n ~* '(^|[^a-z])gs([^a-z]|$)' THEN 30
    WHEN n ILIKE '%primaire%' THEN 99
    WHEN n ILIKE '%coll%ge%' THEN 135
    WHEN n ILIKE '%lyc%e%' THEN 165
    WHEN n ILIKE '%litt%' OR n ILIKE '%roman%' THEN 190
    ELSE 9999
  END
$$;

-- 2) Redéfinir la colonne générée pour inspecter titre + niveau
ALTER TABLE public.produits DROP COLUMN IF EXISTS niveau_ordre;
ALTER TABLE public.produits
  ADD COLUMN niveau_ordre INT
  GENERATED ALWAYS AS (
    public.produit_niveau_ordre(COALESCE(niveau, '') || ' ' || COALESCE(titre, ''))
  ) STORED;

CREATE INDEX IF NOT EXISTS produits_niveau_ordre_titre_idx
  ON public.produits (niveau_ordre, titre);
CREATE INDEX IF NOT EXISTS idx_produits_actif_niveau
  ON public.produits (actif, niveau_ordre, titre);