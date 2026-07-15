
-- 1) Ajouter 'commercial' à l'enum app_role s'il n'existe pas
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'app_role' AND e.enumlabel = 'commercial'
  ) THEN
    ALTER TYPE public.app_role ADD VALUE 'commercial';
  END IF;
END $$;
