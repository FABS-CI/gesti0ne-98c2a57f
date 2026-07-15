ALTER TABLE public.backups
  ADD COLUMN IF NOT EXISTS destination_ref text,
  ADD COLUMN IF NOT EXISTS destination_url text;