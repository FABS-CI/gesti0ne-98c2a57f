ALTER TABLE public.specimens ADD COLUMN IF NOT EXISTS designation text;

UPDATE public.specimens s
SET designation = p.titre
FROM public.produits p
WHERE s.produit_id = p.produit_id AND (s.designation IS NULL OR s.designation = '');