-- ============================================================
-- Lot RLS-1 : fermeture des écritures directes sur les tables sensibles
-- Lecture inchangée (authenticated), écriture encadrée.
-- ============================================================

-- 1. Journal de clôture d'exercice ---------------------------
DROP POLICY IF EXISTS exercice_cloture_journal_auth ON public.exercice_cloture_journal;
CREATE POLICY exercice_cloture_journal_read ON public.exercice_cloture_journal
  FOR SELECT TO authenticated USING (true);
CREATE POLICY exercice_cloture_journal_write ON public.exercice_cloture_journal
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

-- 2. Définitions de workflows --------------------------------
DROP POLICY IF EXISTS auth_all_workflows_def ON public.workflows_definitions;
CREATE POLICY workflows_def_read ON public.workflows_definitions
  FOR SELECT TO authenticated USING (true);
CREATE POLICY workflows_def_write ON public.workflows_definitions
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

-- 3. Soldes d'ouverture clients ------------------------------
DROP POLICY IF EXISTS soldes_ouv_clients_auth ON public.soldes_ouverture_clients;
CREATE POLICY soldes_ouv_clients_read ON public.soldes_ouverture_clients
  FOR SELECT TO authenticated USING (true);
CREATE POLICY soldes_ouv_clients_write ON public.soldes_ouverture_clients
  FOR ALL TO authenticated
  USING (is_admin(auth.uid()) OR has_permission(auth.uid(), 'comptabilite.modifier'))
  WITH CHECK (is_admin(auth.uid()) OR has_permission(auth.uid(), 'comptabilite.modifier'));

-- 4. Soldes d'ouverture fournisseurs -------------------------
DROP POLICY IF EXISTS soldes_ouv_fourn_auth ON public.soldes_ouverture_fournisseurs;
CREATE POLICY soldes_ouv_fourn_read ON public.soldes_ouverture_fournisseurs
  FOR SELECT TO authenticated USING (true);
CREATE POLICY soldes_ouv_fourn_write ON public.soldes_ouverture_fournisseurs
  FOR ALL TO authenticated
  USING (is_admin(auth.uid()) OR has_permission(auth.uid(), 'comptabilite.modifier'))
  WITH CHECK (is_admin(auth.uid()) OR has_permission(auth.uid(), 'comptabilite.modifier'));

-- 5. Paramètres FNE ------------------------------------------
DROP POLICY IF EXISTS auth_fne_settings ON public.fne_settings;
CREATE POLICY fne_settings_read ON public.fne_settings
  FOR SELECT TO authenticated USING (true);
CREATE POLICY fne_settings_write ON public.fne_settings
  FOR ALL TO authenticated
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));

-- 6. Factures FNE --------------------------------------------
DROP POLICY IF EXISTS auth_fne_factures ON public.fne_factures;
CREATE POLICY fne_factures_read ON public.fne_factures
  FOR SELECT TO authenticated USING (true);
CREATE POLICY fne_factures_write ON public.fne_factures
  FOR ALL TO authenticated
  USING (is_admin(auth.uid()) OR has_permission(auth.uid(), 'factures.modifier'))
  WITH CHECK (is_admin(auth.uid()) OR has_permission(auth.uid(), 'factures.modifier'));

-- 7. Modèles de documents ------------------------------------
DROP POLICY IF EXISTS auth_doc_templates ON public.document_templates;
CREATE POLICY doc_templates_read ON public.document_templates
  FOR SELECT TO authenticated USING (true);
CREATE POLICY doc_templates_write ON public.document_templates
  FOR ALL TO authenticated
  USING (is_admin(auth.uid()) OR has_permission(auth.uid(), 'parametres.modifier'))
  WITH CHECK (is_admin(auth.uid()) OR has_permission(auth.uid(), 'parametres.modifier'));

-- 8. Journaux append-only : audit_stock ----------------------
DROP POLICY IF EXISTS auth_write_audit_stock ON public.audit_stock;
CREATE POLICY audit_stock_insert ON public.audit_stock
  FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);

-- 9. Journaux append-only : historique_envois ----------------
DROP POLICY IF EXISTS auth_hist_envois ON public.historique_envois;
CREATE POLICY hist_envois_read ON public.historique_envois
  FOR SELECT TO authenticated USING (true);
CREATE POLICY hist_envois_insert ON public.historique_envois
  FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);

-- 10. Journaux append-only : fne_logs ------------------------
DROP POLICY IF EXISTS auth_fne_logs ON public.fne_logs;
CREATE POLICY fne_logs_read ON public.fne_logs
  FOR SELECT TO authenticated USING (true);
CREATE POLICY fne_logs_insert ON public.fne_logs
  FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);

-- 11. Journal de performance ---------------------------------
DROP POLICY IF EXISTS auth_perf_log ON public.perf_query_log;
CREATE POLICY perf_log_read_admin ON public.perf_query_log
  FOR SELECT TO authenticated USING (is_admin(auth.uid()));
CREATE POLICY perf_log_insert ON public.perf_query_log
  FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
