ALTER TABLE public.specimens
  ADD COLUMN IF NOT EXISTS representant_nom text,
  ADD COLUMN IF NOT EXISTS donneur_nom text;