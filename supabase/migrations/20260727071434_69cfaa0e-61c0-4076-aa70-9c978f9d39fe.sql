ALTER TABLE public.rbac2_roles
  ADD COLUMN IF NOT EXISTS statut text NOT NULL DEFAULT 'actif',
  ADD COLUMN IF NOT EXISTS valide_at timestamptz,
  ADD COLUMN IF NOT EXISTS valide_by uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'rbac2_roles_statut_check'
  ) THEN
    ALTER TABLE public.rbac2_roles
      ADD CONSTRAINT rbac2_roles_statut_check
      CHECK (statut IN ('brouillon','actif','archive'));
  END IF;
END $$;

UPDATE public.rbac2_roles SET statut = 'actif' WHERE statut IS NULL;