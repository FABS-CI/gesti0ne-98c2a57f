
-- ================================================================
-- Aligner les RLS de lecture legacy avec le RBAC (permission_code)
-- Effet : dès qu'un rôle RBAC est attribué avec la permission `voir`
-- du module, la RLS autorise la lecture — plus besoin des anciens
-- rôles historiques (is_sales, is_finance, is_hr, is_stock, is_admin).
-- ================================================================

-- CLIENTS
DROP POLICY IF EXISTS clients_authorized_read ON public.clients;
CREATE POLICY clients_authorized_read ON public.clients FOR SELECT
USING (
  is_sales(auth.uid())
  OR has_any_role(auth.uid(), ARRAY['gestionnaire_stock','service_logistique','responsable_magasinier']::app_role[])
  OR has_permission(auth.uid(), 'clients.voir')
);

-- FACTURES
DROP POLICY IF EXISTS factures_read ON public.factures;
CREATE POLICY factures_read ON public.factures FOR SELECT
USING (is_finance(auth.uid()) OR has_permission(auth.uid(), 'factures.voir'));

-- PAIEMENTS
DROP POLICY IF EXISTS paiements_read ON public.paiements;
CREATE POLICY paiements_read ON public.paiements FOR SELECT
USING (is_finance(auth.uid()) OR has_permission(auth.uid(), 'paiements.voir'));

-- TRANSACTIONS
DROP POLICY IF EXISTS transactions_read ON public.transactions;
CREATE POLICY transactions_read ON public.transactions FOR SELECT
USING (is_finance(auth.uid()) OR has_permission(auth.uid(), 'transactions.voir') OR has_permission(auth.uid(), 'compta.voir'));

-- COMPTA
DROP POLICY IF EXISTS ec_read ON public.ecritures_comptables;
CREATE POLICY ec_read ON public.ecritures_comptables FOR SELECT
USING (is_finance(auth.uid()) OR has_permission(auth.uid(), 'compta.voir'));

DROP POLICY IF EXISTS el_read ON public.ecriture_lignes;
CREATE POLICY el_read ON public.ecriture_lignes FOR SELECT
USING (is_finance(auth.uid()) OR has_permission(auth.uid(), 'compta.voir'));

DROP POLICY IF EXISTS jc_read ON public.journaux_comptables;
CREATE POLICY jc_read ON public.journaux_comptables FOR SELECT
USING (is_finance(auth.uid()) OR has_permission(auth.uid(), 'compta.voir'));

DROP POLICY IF EXISTS pc_read ON public.plan_comptable;
CREATE POLICY pc_read ON public.plan_comptable FOR SELECT
USING (is_finance(auth.uid()) OR has_permission(auth.uid(), 'compta.voir'));

DROP POLICY IF EXISTS exc_read ON public.exercices_comptables;
CREATE POLICY exc_read ON public.exercices_comptables FOR SELECT
USING (is_finance(auth.uid()) OR has_permission(auth.uid(), 'compta.voir'));

DROP POLICY IF EXISTS fne_read ON public.fne_declarations;
CREATE POLICY fne_read ON public.fne_declarations FOR SELECT
USING (is_finance(auth.uid()) OR has_permission(auth.uid(), 'fne.voir') OR has_permission(auth.uid(), 'compta.voir'));

DROP POLICY IF EXISTS paa_read ON public.paiement_annulations_audit;
CREATE POLICY paa_read ON public.paiement_annulations_audit FOR SELECT
USING (is_finance(auth.uid()) OR is_admin(auth.uid()) OR has_permission(auth.uid(), 'paiements.voir'));

-- ACHATS
DROP POLICY IF EXISTS achats_read ON public.achats;
CREATE POLICY achats_read ON public.achats FOR SELECT
USING (is_stock(auth.uid()) OR is_finance(auth.uid()) OR has_permission(auth.uid(), 'achats.voir'));

DROP POLICY IF EXISTS achat_lignes_read ON public.achat_lignes;
CREATE POLICY achat_lignes_read ON public.achat_lignes FOR SELECT
USING (is_stock(auth.uid()) OR is_finance(auth.uid()) OR has_permission(auth.uid(), 'achats.voir'));

-- RH
DROP POLICY IF EXISTS employes_hr_read ON public.employes;
CREATE POLICY employes_hr_read ON public.employes FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'employes.voir'));

DROP POLICY IF EXISTS absences_hr_read ON public.absences;
CREATE POLICY absences_hr_read ON public.absences FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'employes.voir'));

DROP POLICY IF EXISTS conges_hr_read ON public.conges;
CREATE POLICY conges_hr_read ON public.conges FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'employes.voir'));

DROP POLICY IF EXISTS contrats_hr_read ON public.contrats;
CREATE POLICY contrats_hr_read ON public.contrats FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'employes.voir'));

DROP POLICY IF EXISTS evaluations_hr_read ON public.evaluations;
CREATE POLICY evaluations_hr_read ON public.evaluations FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'employes.voir'));

DROP POLICY IF EXISTS departements_hr_read ON public.departements;
CREATE POLICY departements_hr_read ON public.departements FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'employes.voir'));

DROP POLICY IF EXISTS fonctions_hr_read ON public.fonctions;
CREATE POLICY fonctions_hr_read ON public.fonctions FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'employes.voir'));

DROP POLICY IF EXISTS bulletins_hr_read ON public.bulletins_paie;
CREATE POLICY bulletins_hr_read ON public.bulletins_paie FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'paie.voir'));

DROP POLICY IF EXISTS bulletin_lignes_hr_read ON public.bulletin_lignes;
CREATE POLICY bulletin_lignes_hr_read ON public.bulletin_lignes FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'paie.voir'));

DROP POLICY IF EXISTS parametres_paie_hr_read ON public.parametres_paie;
CREATE POLICY parametres_paie_hr_read ON public.parametres_paie FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'paie.voir'));

DROP POLICY IF EXISTS rubriques_paie_hr_read ON public.rubriques_paie;
CREATE POLICY rubriques_paie_hr_read ON public.rubriques_paie FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'paie.voir'));

DROP POLICY IF EXISTS declarations_paie_hr_read ON public.declarations_paie;
CREATE POLICY declarations_paie_hr_read ON public.declarations_paie FOR SELECT
USING (is_hr(auth.uid()) OR has_permission(auth.uid(), 'paie.voir'));

-- STOCK / LOGISTIQUE
DROP POLICY IF EXISTS colisage_resp_read ON public.colisage_responsables;
CREATE POLICY colisage_resp_read ON public.colisage_responsables FOR SELECT
USING (is_stock(auth.uid()) OR is_admin(auth.uid()) OR has_permission(auth.uid(), 'colisage.voir'));

-- RBAC (permet la lecture aux gestionnaires de rôles non-admin)
DROP POLICY IF EXISTS rbac_permissions_admin_read ON public.rbac_permissions;
CREATE POLICY rbac_permissions_admin_read ON public.rbac_permissions FOR SELECT
USING (is_admin(auth.uid()) OR has_permission(auth.uid(), 'roles.voir'));

DROP POLICY IF EXISTS rbac_roles_admin_read ON public.rbac_roles;
CREATE POLICY rbac_roles_admin_read ON public.rbac_roles FOR SELECT
USING (is_admin(auth.uid()) OR has_permission(auth.uid(), 'roles.voir'));

DROP POLICY IF EXISTS rbac_rp_admin_read ON public.rbac_role_permissions;
CREATE POLICY rbac_rp_admin_read ON public.rbac_role_permissions FOR SELECT
USING (is_admin(auth.uid()) OR has_permission(auth.uid(), 'roles.voir'));
