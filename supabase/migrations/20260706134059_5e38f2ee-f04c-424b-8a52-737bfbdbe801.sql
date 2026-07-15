-- Soft-delete columns
ALTER TABLE public.employes
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_employes_deleted_at ON public.employes (deleted_at);

-- Soft delete: marks the employee and audit-logs the action.
CREATE OR REPLACE FUNCTION public.soft_delete_employe(_employe_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp RECORD;
  v_uid UUID := auth.uid();
BEGIN
  SELECT * INTO v_emp FROM public.employes WHERE employe_id = _employe_id AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Employé introuvable ou déjà supprimé';
  END IF;

  UPDATE public.employes
     SET deleted_at = NOW(), deleted_by = v_uid, actif = false
   WHERE employe_id = _employe_id;

  INSERT INTO public.audit_logs (user_id, user_email, action, table_name, record_id, old_values)
  VALUES (v_uid, (SELECT email FROM auth.users WHERE id = v_uid),
          'soft_delete', 'employes', _employe_id::text, to_jsonb(v_emp));
END;
$$;

-- Restore: only allowed while within retention window (default 30 days).
CREATE OR REPLACE FUNCTION public.restore_employe(_employe_id UUID, _retention_days INT DEFAULT 30)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp RECORD;
  v_uid UUID := auth.uid();
BEGIN
  SELECT * INTO v_emp FROM public.employes WHERE employe_id = _employe_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Employé introuvable';
  END IF;
  IF v_emp.deleted_at IS NULL THEN
    RAISE EXCEPTION 'Cet employé n''est pas supprimé';
  END IF;
  IF v_emp.deleted_at < NOW() - (_retention_days || ' days')::INTERVAL THEN
    RAISE EXCEPTION 'Délai de restauration dépassé (% jours)', _retention_days;
  END IF;

  UPDATE public.employes
     SET deleted_at = NULL, deleted_by = NULL, actif = true
   WHERE employe_id = _employe_id;

  INSERT INTO public.audit_logs (user_id, user_email, action, table_name, record_id, new_values)
  VALUES (v_uid, (SELECT email FROM auth.users WHERE id = v_uid),
          'restore', 'employes', _employe_id::text, to_jsonb(v_emp));
END;
$$;

-- Atomic renumber with unique-constraint safety and audit trail.
CREATE OR REPLACE FUNCTION public.renumber_employes_matricules()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
  v_uid UUID := auth.uid();
BEGIN
  -- Two-pass to avoid unique collisions on employes_matricule_key
  WITH ranked AS (
    SELECT employe_id, ROW_NUMBER() OVER (ORDER BY created_at ASC, employe_id ASC) AS rn
    FROM public.employes
    WHERE deleted_at IS NULL
  )
  UPDATE public.employes e
     SET matricule = 'TMP-' || r.rn
    FROM ranked r
   WHERE e.employe_id = r.employe_id;

  WITH ranked AS (
    SELECT employe_id, ROW_NUMBER() OVER (ORDER BY created_at ASC, employe_id ASC) AS rn
    FROM public.employes
    WHERE deleted_at IS NULL
  )
  UPDATE public.employes e
     SET matricule = 'EMP-' || LPAD(r.rn::text, 5, '0')
    FROM ranked r
   WHERE e.employe_id = r.employe_id;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.audit_logs (user_id, user_email, action, table_name, record_id, new_values)
  VALUES (v_uid, (SELECT email FROM auth.users WHERE id = v_uid),
          'renumber_matricules', 'employes', NULL,
          jsonb_build_object('count', v_count, 'at', NOW()));

  RETURN v_count;
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'Conflit de matricules : un matricule identique existe déjà.';
END;
$$;

GRANT EXECUTE ON FUNCTION public.soft_delete_employe(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restore_employe(UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.renumber_employes_matricules() TO authenticated;