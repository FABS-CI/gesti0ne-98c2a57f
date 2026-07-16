
-- conges: drop stale permissive duplicates
DROP POLICY IF EXISTS "conges read auth" ON public.conges;
DROP POLICY IF EXISTS "conges write auth" ON public.conges;

-- colisage_responsables: stock/admin
DROP POLICY IF EXISTS auth_read_colisage_resp ON public.colisage_responsables;
DROP POLICY IF EXISTS auth_write_colisage_resp ON public.colisage_responsables;
CREATE POLICY colisage_resp_read ON public.colisage_responsables FOR SELECT TO authenticated USING (public.is_stock(auth.uid()) OR public.is_admin(auth.uid()));
CREATE POLICY colisage_resp_write ON public.colisage_responsables FOR ALL TO authenticated USING (public.is_stock(auth.uid()) OR public.is_admin(auth.uid())) WITH CHECK (public.is_stock(auth.uid()) OR public.is_admin(auth.uid()));

-- parametres_systeme / parametres_entreprise: admin write, any read
DROP POLICY IF EXISTS auth_read_parametres_systeme ON public.parametres_systeme;
DROP POLICY IF EXISTS auth_write_parametres_systeme ON public.parametres_systeme;
CREATE POLICY parametres_systeme_read ON public.parametres_systeme FOR SELECT TO authenticated USING (true);
CREATE POLICY parametres_systeme_write ON public.parametres_systeme FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS auth_read_parametres_entreprise ON public.parametres_entreprise;
DROP POLICY IF EXISTS auth_write_parametres_entreprise ON public.parametres_entreprise;
CREATE POLICY parametres_entreprise_read ON public.parametres_entreprise FOR SELECT TO authenticated USING (true);
CREATE POLICY parametres_entreprise_write ON public.parametres_entreprise FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

-- rbac_audit_log: INSERT only via SECURITY DEFINER functions (no policy)
DROP POLICY IF EXISTS "rbac_audit insert authenticated" ON public.rbac_audit_log;

-- notifications: users can only insert notifications for themselves
DROP POLICY IF EXISTS "Authenticated insert notifications" ON public.notifications;
CREATE POLICY notifications_insert_self ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR public.is_admin(auth.uid()));
