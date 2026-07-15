
CREATE OR REPLACE FUNCTION public.assert_permission(_perm text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_permission_v2(auth.uid(), _perm) THEN
    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
    INSERT INTO public.rbac_audit_log(user_id, user_email, action, details)
    VALUES (auth.uid(), v_email, 'permission_denied',
      jsonb_build_object('permission', _perm, 'source', 'rpc'));
    RAISE EXCEPTION 'Permission refusée: %', _perm USING ERRCODE = '42501';
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.assert_permission(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_permission_denied(_perm text, _context jsonb DEFAULT '{}'::jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_email text;
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.rbac_audit_log(user_id, user_email, action, details)
  VALUES (auth.uid(), v_email, 'permission_denied',
    jsonb_build_object('permission', _perm, 'source', 'route')
    || COALESCE(_context, '{}'::jsonb));
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_permission_denied(text, jsonb) TO authenticated;
