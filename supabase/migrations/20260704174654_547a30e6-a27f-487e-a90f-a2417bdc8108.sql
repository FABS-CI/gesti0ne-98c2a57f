
DROP POLICY IF EXISTS "sof_select" ON public.soldes_ouverture_fournisseurs;
CREATE POLICY "sof_select" ON public.soldes_ouverture_fournisseurs
  FOR SELECT TO authenticated
  USING (public.is_exercice_admin(auth.uid()) OR public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "soc_select" ON public.soldes_ouverture_clients;
CREATE POLICY "soc_select" ON public.soldes_ouverture_clients
  FOR SELECT TO authenticated
  USING (public.is_exercice_admin(auth.uid()) OR public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "ecj_select" ON public.exercice_cloture_journal;
CREATE POLICY "ecj_select" ON public.exercice_cloture_journal
  FOR SELECT TO authenticated
  USING (public.is_exercice_admin(auth.uid()) OR public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Authenticated can view tournees" ON public.tournees;
CREATE POLICY "Staff can view tournees" ON public.tournees
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "colisage_resp read" ON public.colisage_responsables;
CREATE POLICY "colisage_resp read" ON public.colisage_responsables
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Auth users can read preparateurs" ON public.preparateurs_colisage;
CREATE POLICY "Staff can read preparateurs" ON public.preparateurs_colisage
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "exercices_select" ON public.exercices;
CREATE POLICY "exercices_select" ON public.exercices
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()) OR public.is_exercice_admin(auth.uid()));

DROP POLICY IF EXISTS "rbac_roles readable by authenticated" ON public.rbac_roles;
CREATE POLICY "rbac_roles readable by staff" ON public.rbac_roles
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "rbac_permissions readable by authenticated" ON public.rbac_permissions;
CREATE POLICY "rbac_permissions readable by staff" ON public.rbac_permissions
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));
