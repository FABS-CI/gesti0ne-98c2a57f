
-- list_user_permissions_v2 : renvoie la liste plate des codes permission
-- pour un utilisateur en résolvant l'héritage multiple (rbac2_role_parents)
-- et les deny explicites (rbac2_role_perms.granted = false > grants).
CREATE OR REPLACE FUNCTION public.list_user_permissions_v2(_user_id uuid)
RETURNS TABLE (permission_code text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH RECURSIVE
  -- rôles directs de l'utilisateur
  direct_roles AS (
    SELECT ur.role_code FROM public.rbac2_user_roles ur WHERE ur.user_id = _user_id
  ),
  -- fermeture transitive via rbac2_role_parents
  all_roles AS (
    SELECT role_code FROM direct_roles
    UNION
    SELECT rp.parent_code
    FROM public.rbac2_role_parents rp
    JOIN all_roles ar ON ar.role_code = rp.role_code
  ),
  -- agrège grants et deny sur l'ensemble des rôles
  perms AS (
    SELECT rp.perm_code,
           bool_or(rp.granted)      AS any_grant,
           bool_or(NOT rp.granted)  AS any_deny
    FROM public.rbac2_role_perms rp
    JOIN all_roles ar ON ar.role_code = rp.role_code
    GROUP BY rp.perm_code
  )
  SELECT perm_code
  FROM perms
  WHERE any_grant = true AND any_deny = false;
$$;

REVOKE ALL ON FUNCTION public.list_user_permissions_v2(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_user_permissions_v2(uuid) TO authenticated, service_role;
