
ALTER TABLE public.depots
  ADD COLUMN IF NOT EXISTS type_depot text NOT NULL DEFAULT 'secondaire',
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS pays text DEFAULT 'Côte d''Ivoire',
  ADD COLUMN IF NOT EXISTS commune text,
  ADD COLUMN IF NOT EXISTS quartier text,
  ADD COLUMN IF NOT EXISTS code_postal text,
  ADD COLUMN IF NOT EXISTS latitude numeric,
  ADD COLUMN IF NOT EXISTS longitude numeric,
  ADD COLUMN IF NOT EXISTS responsable_email text,
  ADD COLUMN IF NOT EXISTS telephone text,
  ADD COLUMN IF NOT EXISTS capacite numeric,
  ADD COLUMN IF NOT EXISTS is_principal boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS depots_one_principal
  ON public.depots ((true)) WHERE is_principal = true;
