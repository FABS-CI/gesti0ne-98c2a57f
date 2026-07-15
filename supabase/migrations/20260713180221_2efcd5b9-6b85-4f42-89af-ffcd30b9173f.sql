
-- Fast permission helper: direct lookup, no recursion / view expansion.
CREATE OR REPLACE FUNCTION public.has_rbac_permission_fast(_user_id uuid, _perm text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.rbac_user_roles ur
    JOIN public.rbac_roles r ON r.role_id = ur.role_id AND r.actif
    JOIN public.rbac_role_permissions rp ON rp.role_id = ur.role_id
    WHERE ur.user_id = _user_id
      AND rp.permission_code = _perm
      AND rp.accorde = true
  ) OR EXISTS (
    SELECT 1
    FROM public.rbac_user_roles ur
    JOIN public.rbac_roles r ON r.role_id = ur.role_id AND r.actif
    WHERE ur.user_id = _user_id AND r.code = 'super_admin'
  ) OR EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = _user_id AND ur.role = 'super_admin'::app_role
  );
$$;

GRANT EXECUTE ON FUNCTION public.has_rbac_permission_fast(uuid, text) TO authenticated, service_role;

-- Rewrite the clients SELECT policy to use the fast helper.
DROP POLICY IF EXISTS "clients read via rbac or commercial" ON public.clients;
CREATE POLICY "clients read via rbac or commercial"
ON public.clients
FOR SELECT
TO authenticated
USING (
  public.has_commercial_access(auth.uid())
  OR public.has_rbac_permission_fast(auth.uid(), 'clients_dashboard.voir')
  OR public.has_rbac_permission_fast(auth.uid(), 'clients.voir')
);
