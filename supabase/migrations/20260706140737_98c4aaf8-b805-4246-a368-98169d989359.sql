-- Planification des sauvegardes
CREATE TABLE public.backup_schedules (
  schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  nom TEXT NOT NULL,
  frequence TEXT NOT NULL CHECK (frequence IN ('horaire','quotidien','hebdomadaire','mensuel')),
  type_sauvegarde TEXT NOT NULL CHECK (type_sauvegarde IN ('complete','base','documents')),
  destination TEXT NOT NULL DEFAULT 'local' CHECK (destination IN ('local','google_drive','onedrive','dropbox','s3','b2','wasabi','r2','ftp','nas')),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  retention_count INTEGER NOT NULL DEFAULT 10 CHECK (retention_count BETWEEN 1 AND 500),
  last_run_at TIMESTAMPTZ,
  next_run_at TIMESTAMPTZ
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.backup_schedules TO authenticated;
GRANT ALL ON public.backup_schedules TO service_role;

ALTER TABLE public.backup_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bs_admin_select" ON public.backup_schedules FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "bs_admin_insert" ON public.backup_schedules FOR INSERT TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "bs_admin_update" ON public.backup_schedules FOR UPDATE TO authenticated
USING (public.has_role(auth.uid(), 'super_admin'))
WITH CHECK (public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "bs_admin_delete" ON public.backup_schedules FOR DELETE TO authenticated
USING (public.has_role(auth.uid(), 'super_admin'));

CREATE TRIGGER trg_backup_schedules_updated_at
BEFORE UPDATE ON public.backup_schedules
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Purge des anciennes sauvegardes (conserve N dernieres reussies par type)
CREATE OR REPLACE FUNCTION public.purger_anciennes_sauvegardes(
  _type TEXT DEFAULT NULL,
  _retention INT DEFAULT 10
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := (SELECT auth.uid());
  v_email TEXT;
  v_deleted INT := 0;
  v_ids UUID[];
BEGIN
  IF NOT public.has_role(v_uid, 'super_admin') THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  IF _retention < 1 THEN
    RAISE EXCEPTION 'Retention doit être >= 1';
  END IF;

  WITH ranked AS (
    SELECT backup_id,
           ROW_NUMBER() OVER (PARTITION BY type ORDER BY created_at DESC) AS rn
    FROM public.backups
    WHERE statut = 'succes' AND (_type IS NULL OR type = _type)
  )
  SELECT COALESCE(array_agg(backup_id), '{}') INTO v_ids
  FROM ranked WHERE rn > _retention;

  DELETE FROM public.backups WHERE backup_id = ANY(v_ids);
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
  INSERT INTO public.audit_logs (user_id, user_email, action, table_name, new_values)
  VALUES (
    v_uid, v_email, 'backup_purge', 'backups',
    jsonb_build_object('type', _type, 'retention', _retention, 'supprimees', v_deleted)
  );

  RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.purger_anciennes_sauvegardes(TEXT, INT) TO authenticated;