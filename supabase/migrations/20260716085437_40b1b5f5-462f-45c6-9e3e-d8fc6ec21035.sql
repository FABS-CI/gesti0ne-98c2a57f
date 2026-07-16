
-- Helper: check any role in a list
CREATE OR REPLACE FUNCTION public.has_any_role(_user_id uuid, _roles app_role[])
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id=_user_id AND role = ANY(_roles));
$$;
REVOKE EXECUTE ON FUNCTION public.has_any_role(uuid, app_role[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_any_role(uuid, app_role[]) TO authenticated, service_role;

-- Semantic predicates
CREATE OR REPLACE FUNCTION public.is_admin(_uid uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT public.has_any_role(_uid, ARRAY['super_admin','directeur_general']::app_role[]);
$$;
CREATE OR REPLACE FUNCTION public.is_hr(_uid uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT public.has_any_role(_uid, ARRAY['super_admin','directeur_general']::app_role[]);
$$;
CREATE OR REPLACE FUNCTION public.is_finance(_uid uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT public.has_any_role(_uid, ARRAY['super_admin','directeur_general','comptable','assistante_comptable']::app_role[]);
$$;
CREATE OR REPLACE FUNCTION public.is_sales(_uid uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT public.has_any_role(_uid, ARRAY['super_admin','directeur_general','directeur_commercial','secretariat','assistante','comptable','assistante_comptable']::app_role[]);
$$;
CREATE OR REPLACE FUNCTION public.is_stock(_uid uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT public.has_any_role(_uid, ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier','service_logistique']::app_role[]);
$$;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid), public.is_hr(uuid), public.is_finance(uuid), public.is_sales(uuid), public.is_stock(uuid) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.is_admin(uuid), public.is_hr(uuid), public.is_finance(uuid), public.is_sales(uuid), public.is_stock(uuid) FROM anon;

-- ===== HR: employes, contrats, bulletins_paie, bulletin_lignes =====
DROP POLICY IF EXISTS "employes read auth" ON public.employes;
DROP POLICY IF EXISTS "employes write auth" ON public.employes;
CREATE POLICY employes_hr_read ON public.employes FOR SELECT TO authenticated USING (public.is_hr(auth.uid()));
CREATE POLICY employes_hr_write ON public.employes FOR ALL TO authenticated USING (public.is_hr(auth.uid())) WITH CHECK (public.is_hr(auth.uid()));

DROP POLICY IF EXISTS auth_read_contrats ON public.contrats;
DROP POLICY IF EXISTS auth_write_contrats ON public.contrats;
CREATE POLICY contrats_hr_read ON public.contrats FOR SELECT TO authenticated USING (public.is_hr(auth.uid()));
CREATE POLICY contrats_hr_write ON public.contrats FOR ALL TO authenticated USING (public.is_hr(auth.uid())) WITH CHECK (public.is_hr(auth.uid()));

DROP POLICY IF EXISTS auth_read_bulletins_paie ON public.bulletins_paie;
DROP POLICY IF EXISTS auth_write_bulletins_paie ON public.bulletins_paie;
CREATE POLICY bulletins_hr_read ON public.bulletins_paie FOR SELECT TO authenticated USING (public.is_hr(auth.uid()));
CREATE POLICY bulletins_hr_write ON public.bulletins_paie FOR ALL TO authenticated USING (public.is_hr(auth.uid())) WITH CHECK (public.is_hr(auth.uid()));

DROP POLICY IF EXISTS auth_read_bulletin_lignes ON public.bulletin_lignes;
DROP POLICY IF EXISTS auth_write_bulletin_lignes ON public.bulletin_lignes;
CREATE POLICY bulletin_lignes_hr_read ON public.bulletin_lignes FOR SELECT TO authenticated USING (public.is_hr(auth.uid()));
CREATE POLICY bulletin_lignes_hr_write ON public.bulletin_lignes FOR ALL TO authenticated USING (public.is_hr(auth.uid())) WITH CHECK (public.is_hr(auth.uid()));

-- Related HR tables
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY['absences','conges','evaluations','declarations_paie','rubriques_paie','parametres_paie','departements','fonctions']) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'auth_read_'||t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'auth_write_'||t, t);
    BEGIN
      EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.is_hr(auth.uid()))', t||'_hr_read', t);
      EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (public.is_hr(auth.uid())) WITH CHECK (public.is_hr(auth.uid()))', t||'_hr_write', t);
    EXCEPTION WHEN duplicate_object THEN NULL; END;
  END LOOP;
END $$;

-- ===== Clients: sales/admin =====
DROP POLICY IF EXISTS "Authenticated read clients" ON public.clients;
DROP POLICY IF EXISTS "Authenticated write clients" ON public.clients;
CREATE POLICY clients_sales_read ON public.clients FOR SELECT TO authenticated USING (public.is_sales(auth.uid()));
CREATE POLICY clients_sales_write ON public.clients FOR ALL TO authenticated USING (public.is_sales(auth.uid())) WITH CHECK (public.is_sales(auth.uid()));

-- ===== Audit logs: admin read, INSERT via SECURITY DEFINER RPC only =====
DROP POLICY IF EXISTS "audit read authenticated" ON public.audit_logs;
DROP POLICY IF EXISTS "audit insert authenticated" ON public.audit_logs;
CREATE POLICY audit_logs_admin_read ON public.audit_logs FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));
-- No INSERT policy: log_audit_event / log_user_login / track_user_action are SECURITY DEFINER and bypass RLS

-- ===== Backups: admin only =====
DROP POLICY IF EXISTS "backups read authenticated" ON public.backups;
DROP POLICY IF EXISTS "backups write authenticated" ON public.backups;
CREATE POLICY backups_admin_read ON public.backups FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY backups_admin_write ON public.backups FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Authenticated read backup_schedules" ON public.backup_schedules;
DROP POLICY IF EXISTS "Authenticated manage backup_schedules" ON public.backup_schedules;
CREATE POLICY backup_schedules_admin_read ON public.backup_schedules FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY backup_schedules_admin_write ON public.backup_schedules FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

-- ===== Finance tables: finance/admin =====
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY['transactions','factures','paiements','ecritures_comptables','ecriture_lignes','plan_comptable','journaux_comptables','exercices_comptables','achats','achat_lignes','fne_declarations','paiement_annulations_audit']) LOOP
    -- drop known permissive policy names
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t||' read auth', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t||' write auth', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'auth_read_'||t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'auth_write_'||t, t);
  END LOOP;
END $$;
-- Sales roles need to READ factures/paiements for their workflows; writes stay finance/admin
CREATE POLICY factures_read ON public.factures FOR SELECT TO authenticated USING (public.is_sales(auth.uid()));
CREATE POLICY factures_write ON public.factures FOR ALL TO authenticated USING (public.is_finance(auth.uid())) WITH CHECK (public.is_finance(auth.uid()));
CREATE POLICY paiements_read ON public.paiements FOR SELECT TO authenticated USING (public.is_sales(auth.uid()));
CREATE POLICY paiements_write ON public.paiements FOR ALL TO authenticated USING (public.is_finance(auth.uid())) WITH CHECK (public.is_finance(auth.uid()));
CREATE POLICY transactions_read ON public.transactions FOR SELECT TO authenticated USING (public.is_finance(auth.uid()));
CREATE POLICY transactions_write ON public.transactions FOR ALL TO authenticated USING (public.is_finance(auth.uid())) WITH CHECK (public.is_finance(auth.uid()));
CREATE POLICY ec_read ON public.ecritures_comptables FOR SELECT TO authenticated USING (public.is_finance(auth.uid()));
CREATE POLICY ec_write ON public.ecritures_comptables FOR ALL TO authenticated USING (public.is_finance(auth.uid())) WITH CHECK (public.is_finance(auth.uid()));
CREATE POLICY el_read ON public.ecriture_lignes FOR SELECT TO authenticated USING (public.is_finance(auth.uid()));
CREATE POLICY el_write ON public.ecriture_lignes FOR ALL TO authenticated USING (public.is_finance(auth.uid())) WITH CHECK (public.is_finance(auth.uid()));
CREATE POLICY pc_read ON public.plan_comptable FOR SELECT TO authenticated USING (public.is_finance(auth.uid()));
CREATE POLICY pc_write ON public.plan_comptable FOR ALL TO authenticated USING (public.is_finance(auth.uid())) WITH CHECK (public.is_finance(auth.uid()));
CREATE POLICY jc_read ON public.journaux_comptables FOR SELECT TO authenticated USING (public.is_finance(auth.uid()));
CREATE POLICY jc_write ON public.journaux_comptables FOR ALL TO authenticated USING (public.is_finance(auth.uid())) WITH CHECK (public.is_finance(auth.uid()));
CREATE POLICY exc_read ON public.exercices_comptables FOR SELECT TO authenticated USING (public.is_finance(auth.uid()));
CREATE POLICY exc_write ON public.exercices_comptables FOR ALL TO authenticated USING (public.is_finance(auth.uid())) WITH CHECK (public.is_finance(auth.uid()));
CREATE POLICY achats_read ON public.achats FOR SELECT TO authenticated USING (public.is_stock(auth.uid()) OR public.is_finance(auth.uid()));
CREATE POLICY achats_write ON public.achats FOR ALL TO authenticated USING (public.is_stock(auth.uid()) OR public.is_finance(auth.uid())) WITH CHECK (public.is_stock(auth.uid()) OR public.is_finance(auth.uid()));
CREATE POLICY achat_lignes_read ON public.achat_lignes FOR SELECT TO authenticated USING (public.is_stock(auth.uid()) OR public.is_finance(auth.uid()));
CREATE POLICY achat_lignes_write ON public.achat_lignes FOR ALL TO authenticated USING (public.is_stock(auth.uid()) OR public.is_finance(auth.uid())) WITH CHECK (public.is_stock(auth.uid()) OR public.is_finance(auth.uid()));
CREATE POLICY fne_read ON public.fne_declarations FOR SELECT TO authenticated USING (public.is_finance(auth.uid()));
CREATE POLICY fne_write ON public.fne_declarations FOR ALL TO authenticated USING (public.is_finance(auth.uid())) WITH CHECK (public.is_finance(auth.uid()));
CREATE POLICY paa_read ON public.paiement_annulations_audit FOR SELECT TO authenticated USING (public.is_finance(auth.uid()) OR public.is_admin(auth.uid()));
CREATE POLICY paa_write ON public.paiement_annulations_audit FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

-- ===== RBAC: read admin-only =====
DROP POLICY IF EXISTS "rbac_roles readable by authenticated" ON public.rbac_roles;
DROP POLICY IF EXISTS "rbac_permissions readable by authenticated" ON public.rbac_permissions;
DROP POLICY IF EXISTS "rbac_rp readable by authenticated" ON public.rbac_role_permissions;
CREATE POLICY rbac_roles_admin_read ON public.rbac_roles FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY rbac_permissions_admin_read ON public.rbac_permissions FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY rbac_rp_admin_read ON public.rbac_role_permissions FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));

-- ===== Storage: product-covers write = admin/stock =====
DROP POLICY IF EXISTS "authenticated insert product-covers" ON storage.objects;
DROP POLICY IF EXISTS "authenticated update product-covers" ON storage.objects;
DROP POLICY IF EXISTS "authenticated delete product-covers" ON storage.objects;
CREATE POLICY "product-covers insert privileged" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'product-covers' AND (public.is_admin(auth.uid()) OR public.is_stock(auth.uid())));
CREATE POLICY "product-covers update privileged" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'product-covers' AND (public.is_admin(auth.uid()) OR public.is_stock(auth.uid())))
  WITH CHECK (bucket_id = 'product-covers' AND (public.is_admin(auth.uid()) OR public.is_stock(auth.uid())));
CREATE POLICY "product-covers delete privileged" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'product-covers' AND (public.is_admin(auth.uid()) OR public.is_stock(auth.uid())));
