-- Lot RLS-3 : restriction des lectures sur les tables sensibles

-- Achats / coûts d'entrée
DROP POLICY IF EXISTS auth_read_approvisionnements ON public.approvisionnements;
CREATE POLICY appro_read_perm ON public.approvisionnements FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'achats.voir') OR has_role(auth.uid(),'super_admin'::app_role));

DROP POLICY IF EXISTS auth_read_approvisionnement_lignes ON public.approvisionnement_lignes;
CREATE POLICY appro_lignes_read_perm ON public.approvisionnement_lignes FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'achats.voir') OR has_role(auth.uid(),'super_admin'::app_role));

-- Fournisseurs
DROP POLICY IF EXISTS "fournisseurs read auth" ON public.fournisseurs;
CREATE POLICY fournisseurs_read_perm ON public.fournisseurs FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'fournisseurs.voir') OR has_permission_v2(auth.uid(),'achats.voir') OR has_role(auth.uid(),'super_admin'::app_role));

-- Coûts logistiques
DROP POLICY IF EXISTS auth_read_couts_logistiques ON public.couts_logistiques;
CREATE POLICY couts_log_read_perm ON public.couts_logistiques FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'couts_logistiques.voir') OR has_role(auth.uid(),'super_admin'::app_role));

DROP POLICY IF EXISTS couts_log_audit_read_auth ON public.couts_logistiques_audit;
CREATE POLICY couts_log_audit_read_perm ON public.couts_logistiques_audit FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'couts_logistiques.voir') OR has_role(auth.uid(),'super_admin'::app_role));

-- Comptabilité : soldes d'ouverture et journal de clôture
DROP POLICY IF EXISTS soldes_ouv_clients_read ON public.soldes_ouverture_clients;
CREATE POLICY soldes_ouv_clients_read_perm ON public.soldes_ouverture_clients FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'comptabilite.voir') OR has_permission_v2(auth.uid(),'exercices.voir') OR has_role(auth.uid(),'super_admin'::app_role));

DROP POLICY IF EXISTS soldes_ouv_fourn_read ON public.soldes_ouverture_fournisseurs;
CREATE POLICY soldes_ouv_fourn_read_perm ON public.soldes_ouverture_fournisseurs FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'comptabilite.voir') OR has_permission_v2(auth.uid(),'exercices.voir') OR has_role(auth.uid(),'super_admin'::app_role));

DROP POLICY IF EXISTS exercice_cloture_journal_read ON public.exercice_cloture_journal;
CREATE POLICY exercice_cloture_journal_read_perm ON public.exercice_cloture_journal FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'exercices.voir') OR has_permission_v2(auth.uid(),'comptabilite.voir') OR has_role(auth.uid(),'super_admin'::app_role));

-- FNE (contient des paramètres d'intégration sensibles)
DROP POLICY IF EXISTS fne_settings_read ON public.fne_settings;
CREATE POLICY fne_settings_read_perm ON public.fne_settings FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'fne.acceder_parametres') OR has_role(auth.uid(),'super_admin'::app_role));

DROP POLICY IF EXISTS fne_logs_read ON public.fne_logs;
CREATE POLICY fne_logs_read_perm ON public.fne_logs FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'fne.voir') OR has_role(auth.uid(),'super_admin'::app_role));

-- Paramètres système
DROP POLICY IF EXISTS parametres_systeme_read ON public.parametres_systeme;
CREATE POLICY parametres_systeme_read_perm ON public.parametres_systeme FOR SELECT TO authenticated
USING (has_permission_v2(auth.uid(),'parametres.voir') OR has_role(auth.uid(),'super_admin'::app_role));
