
CREATE OR REPLACE FUNCTION public.purger_anciennes_sauvegardes(
  _type text DEFAULT NULL,
  _retention integer DEFAULT 30
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_role(auth.uid(), 'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = '42501';
  END IF;

  WITH deleted AS (
    DELETE FROM public.backups
    WHERE created_at < now() - make_interval(days => GREATEST(_retention, 0))
      AND (_type IS NULL OR type = _type)
    RETURNING backup_id
  )
  SELECT count(*)::int INTO v_count FROM deleted;

  RETURN COALESCE(v_count, 0);
END;
$$;

REVOKE ALL ON FUNCTION public.purger_anciennes_sauvegardes(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purger_anciennes_sauvegardes(text, integer) TO authenticated;
