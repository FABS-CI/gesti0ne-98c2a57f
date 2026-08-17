CREATE OR REPLACE VIEW public.rbac3_user_permissions AS
SELECT DISTINCT
    ur.user_id,
    rp.perm_code as permission_code
FROM public.rbac3_user_roles ur
JOIN public.rbac3_role_permissions rp ON ur.role_code = rp.role_code;

GRANT SELECT ON public.rbac3_user_permissions TO authenticated, anon;

CREATE OR REPLACE FUNCTION public.rbac3_can(_perm text, _user_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_is_super boolean;
  v_has_perm boolean;
BEGIN
  IF _user_id IS NULL THEN RETURN false; END IF;

  -- Le super_admin peut TOUT faire
  SELECT EXISTS (
    SELECT 1 FROM public.rbac3_user_roles WHERE user_id = _user_id AND role_code = 'super_admin'
  ) INTO v_is_super;

  IF v_is_super THEN RETURN true; END IF;

  -- Sinon check permission spécifique (v3)
  SELECT EXISTS (
    SELECT 1 FROM public.rbac3_user_permissions 
    WHERE user_id = _user_id AND permission_code = _perm
  ) INTO v_has_perm;

  RETURN v_has_perm;
END; $function$;