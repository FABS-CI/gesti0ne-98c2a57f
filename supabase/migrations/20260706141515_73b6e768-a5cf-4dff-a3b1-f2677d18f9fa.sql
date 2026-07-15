ALTER TABLE public.backups
  ADD COLUMN IF NOT EXISTS sha256 text,
  ADD COLUMN IF NOT EXISTS verifie boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verifie_at timestamptz,
  ADD COLUMN IF NOT EXISTS verifie_methode text;