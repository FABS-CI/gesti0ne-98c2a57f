CREATE OR REPLACE FUNCTION public.list_user_permissions(_user_id uuid)
RETURNS TABLE(permission_code text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '42501';
  END IF;

  IF auth.uid() <> _user_id
     AND NOT public.has_role(auth.uid(), 'super_admin'::public.app_role) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT p.code
  FROM public.rbac_permissions p
  WHERE EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE ur.user_id = _user_id
      AND ur.role = 'super_admin'::public.app_role
  )
  OR EXISTS (
    SELECT 1
    FROM public.rbac_user_roles ur
    JOIN public.rbac_roles r ON r.role_id = ur.role_id
    WHERE ur.user_id = _user_id
      AND r.code = 'super_admin'
      AND r.actif
  )
  UNION
  SELECT DISTINCT rp.permission_code
  FROM public.rbac_user_roles ur
  JOIN public.rbac_roles r ON r.role_id = ur.role_id AND r.actif
  JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
  JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
  WHERE ur.user_id = _user_id
    AND rp.accorde = true
  UNION
  SELECT DISTINCT rp.permission_code
  FROM public.user_roles ur
  JOIN public.rbac_roles r ON r.code = ur.role::text AND r.actif
  JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
  JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
  WHERE ur.user_id = _user_id
    AND rp.accorde = true;
END;
$function$;

REVOKE ALL ON FUNCTION public.list_user_permissions(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_user_permissions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_user_permissions(uuid) TO service_role;