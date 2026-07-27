CREATE OR REPLACE FUNCTION public.prevent_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF coalesce(current_setting('app.audit_purge', true), '') = 'on' AND TG_OP = 'DELETE' THEN
    RETURN NULL;
  END IF;
  RAISE EXCEPTION 'Journal d''audit inaltérable : % interdit sur %', TG_OP, TG_TABLE_NAME
    USING ERRCODE = '42501';
END;
$$;

CREATE OR REPLACE FUNCTION public.purge_audit_logs_expired()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  PERFORM set_config('app.audit_purge', 'on', true);
  DELETE FROM public.audit_logs
  WHERE created_at < now() - interval '90 days';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  PERFORM set_config('app.audit_purge', 'off', true);
  RETURN v_deleted;
END;
$$;