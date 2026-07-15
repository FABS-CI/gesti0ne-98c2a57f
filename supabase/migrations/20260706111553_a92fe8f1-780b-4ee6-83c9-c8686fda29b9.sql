
ALTER TABLE public.gares
  ADD COLUMN IF NOT EXISTS transporteur_id uuid
  REFERENCES public.transporteurs(transporteur_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_gares_transporteur ON public.gares(transporteur_id);

-- Rattachement des gares compagnie-spécifiques
UPDATE public.gares g SET transporteur_id = t.transporteur_id
FROM public.transporteurs t
WHERE g.transporteur_id IS NULL
  AND (
    (g.nom ILIKE '%UTB%' AND t.nom = 'UTB / AHT')
    OR (g.nom ILIKE '%TSR%' AND t.nom = 'TSR Transport')
    OR (g.nom ILIKE '%OT-CI%' AND t.nom ILIKE 'Ocean%')
    OR (g.nom ILIKE '%Ocean Transport%' AND t.nom = 'Ocean Côte d''Ivoire Transport')
    OR (g.nom ILIKE '%SBTA%' AND g.nom NOT ILIKE '%San Pedro%' AND t.nom = 'SBTA')
    OR (g.nom ILIKE '%SBTA%San Pedro%' AND t.nom = 'SBTA San Pedro')
    OR (g.nom ILIKE 'Gare ST %' AND t.nom = 'ST Transport')
  );
