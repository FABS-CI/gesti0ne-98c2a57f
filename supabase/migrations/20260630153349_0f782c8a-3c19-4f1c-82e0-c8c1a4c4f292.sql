
-- Fix profiles SELECT policy: users can only read their own profile
DROP POLICY IF EXISTS "Profiles readable by authenticated" ON public.profiles;
CREATE POLICY "Users read own profile"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Fix user_roles: only super_admin can insert/update/delete
DROP POLICY IF EXISTS "Only super admin can insert roles" ON public.user_roles;
DROP POLICY IF EXISTS "Only super admin can update roles" ON public.user_roles;
DROP POLICY IF EXISTS "Only super admin can delete roles" ON public.user_roles;

CREATE POLICY "Only super admin can insert roles"
  ON public.user_roles FOR INSERT
  TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'));

CREATE POLICY "Only super admin can update roles"
  ON public.user_roles FOR UPDATE
  TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'));

CREATE POLICY "Only super admin can delete roles"
  ON public.user_roles FOR DELETE
  TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'));
