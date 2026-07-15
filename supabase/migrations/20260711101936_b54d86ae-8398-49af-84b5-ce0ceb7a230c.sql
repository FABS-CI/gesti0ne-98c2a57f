ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS prenom text,
  ADD COLUMN IF NOT EXISTS telephone text,
  ADD COLUMN IF NOT EXISTS fonction text,
  ADD COLUMN IF NOT EXISTS departement text;