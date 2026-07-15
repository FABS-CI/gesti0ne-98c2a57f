-- profiles: admins (super_admin / directeur_general) lisent tous les profils
CREATE POLICY "Admins read all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role])
);

-- rbac_role_permissions: élargir lecture à is_staff
DROP POLICY IF EXISTS "rbac_rp readable by admin" ON public.rbac_role_permissions;

CREATE POLICY "rbac_rp readable by staff"
ON public.rbac_role_permissions
FOR SELECT
TO authenticated
USING ((SELECT public.is_staff((SELECT auth.uid()))));