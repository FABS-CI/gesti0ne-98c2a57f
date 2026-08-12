
-- 1. Sauvegarde de sécurité de la table existante
CREATE TABLE IF NOT EXISTS public.backups_security_backup AS SELECT * FROM public.backups;

-- 2. Création des types enum pour la traçabilité
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'backup_trigger_type') THEN
        CREATE TYPE public.backup_trigger_type AS ENUM ('AUTOMATIC', 'MANUAL');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'backup_scope_type') THEN
        CREATE TYPE public.backup_scope_type AS ENUM ('GLOBAL', 'PROJECT');
    END IF;
END $$;

-- 3. Mise à jour de la table backups
ALTER TABLE public.backups 
ADD COLUMN IF NOT EXISTS project_id UUID,
ADD COLUMN IF NOT EXISTS project_name TEXT,
ADD COLUMN IF NOT EXISTS trigger_type public.backup_trigger_type DEFAULT 'MANUAL',
ADD COLUMN IF NOT EXISTS scope_type public.backup_scope_type DEFAULT 'GLOBAL',
ADD COLUMN IF NOT EXISTS error_message TEXT,
ADD COLUMN IF NOT EXISTS run_id TEXT;

-- 4. Nettoyage et mise en conformité des colonnes existantes (si nécessaire)
-- On garde started_at (déjà présent) et finished_at (déjà présent).

-- 5. Fonction pour le calcul de la prochaine exécution
CREATE OR REPLACE FUNCTION public.get_next_backup_run()
RETURNS TIMESTAMP WITH TIME ZONE
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (SELECT finished_at + interval '3 hours' 
     FROM public.backups 
     WHERE statut = 'succes' AND trigger_type = 'AUTOMATIC'
     ORDER BY finished_at DESC 
     LIMIT 1),
    NOW() + interval '3 hours'
  );
$$;

GRANT SELECT ON public.backups_security_backup TO authenticated;
GRANT ALL ON public.backups_security_backup TO service_role;
