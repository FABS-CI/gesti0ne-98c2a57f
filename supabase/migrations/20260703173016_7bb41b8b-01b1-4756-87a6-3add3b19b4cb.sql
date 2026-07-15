CREATE OR REPLACE FUNCTION public.assert_permission(_perm text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_email text;
  v_roles text[];
  v_rbac_role_ids uuid[];
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;

  IF NOT public.has_permission_v2(auth.uid(), _perm) THEN
    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();

    SELECT array_agg(role::text)
      INTO v_roles
      FROM public.user_roles
      WHERE user_id = auth.uid();

    SELECT array_agg(role_id)
      INTO v_rbac_role_ids
      FROM public.rbac_user_roles
      WHERE user_id = auth.uid();

    INSERT INTO public.rbac_audit_log(user_id, user_email, action, details)
    VALUES (
      auth.uid(),
      v_email,
      'permission_denied',
      jsonb_build_object(
        'permission', _perm,
        'source', 'rpc',
        'app_roles', COALESCE(v_roles, ARRAY[]::text[]),
        'rbac_role_ids', COALESCE(v_rbac_role_ids, ARRAY[]::uuid[]),
        'at', now()
      )
    );

    RAISE EXCEPTION 'Permission refusée: %', _perm USING ERRCODE = '42501';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.log_permission_denied(_perm text, _context jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_email text;
  v_roles text[];
  v_rbac_role_ids uuid[];
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();

  SELECT array_agg(role::text)
    INTO v_roles
    FROM public.user_roles
    WHERE user_id = auth.uid();

  SELECT array_agg(role_id)
    INTO v_rbac_role_ids
    FROM public.rbac_user_roles
    WHERE user_id = auth.uid();

  INSERT INTO public.rbac_audit_log(user_id, user_email, action, details)
  VALUES (
    auth.uid(),
    v_email,
    'permission_denied',
    jsonb_build_object(
      'permission', _perm,
      'source', 'route',
      'app_roles', COALESCE(v_roles, ARRAY[]::text[]),
      'rbac_role_ids', COALESCE(v_rbac_role_ids, ARRAY[]::uuid[]),
      'at', now()
    ) || COALESCE(_context, '{}'::jsonb)
  );
END;
$function$;

CREATE INDEX IF NOT EXISTS idx_rbac_audit_log_action_created
  ON public.rbac_audit_log(action, created_at DESC);