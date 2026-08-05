ALTER TABLE public.fournisseurs ADD COLUMN IF NOT EXISTS contact text;
GRANT SELECT, INSERT, UPDATE ON public.fournisseurs TO authenticated;