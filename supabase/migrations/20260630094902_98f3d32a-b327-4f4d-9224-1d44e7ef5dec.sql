
ALTER TABLE public.livraisons
  ADD COLUMN IF NOT EXISTS tournee_id UUID REFERENCES public.tournees(tournee_id) ON DELETE SET NULL;
ALTER TABLE public.expeditions
  ADD COLUMN IF NOT EXISTS tournee_id UUID REFERENCES public.tournees(tournee_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_livraisons_tournee ON public.livraisons(tournee_id);
CREATE INDEX IF NOT EXISTS idx_expeditions_tournee ON public.expeditions(tournee_id);
