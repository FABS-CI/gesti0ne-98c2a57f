DROP POLICY IF EXISTS "Profiles super admins manage all" ON public.profiles;
CREATE POLICY "profiles_admin_manage" ON public.profiles FOR ALL TO authenticated
  USING (rbac3_can('administration.modifier')) WITH CHECK (rbac3_can('administration.modifier'));

DROP POLICY IF EXISTS "Profiles users update own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id OR rbac3_can('administration.modifier'))
  WITH CHECK (auth.uid() = id OR rbac3_can('administration.modifier'));

DROP POLICY IF EXISTS notifications_insert_self ON public.notifications;
CREATE POLICY notifications_insert_self ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR rbac3_can('administration.modifier'));

DROP POLICY IF EXISTS paa_write ON public.paiement_annulations_audit;
CREATE POLICY paa_write ON public.paiement_annulations_audit FOR ALL TO authenticated
  USING (rbac3_can('paiements.modifier')) WITH CHECK (rbac3_can('paiements.modifier'));

DROP POLICY IF EXISTS wf_appr_all ON public.workflow_approvals;
CREATE POLICY wf_appr_all ON public.workflow_approvals FOR ALL TO authenticated
  USING (rbac3_can('administration.valider') OR rbac3_can('administration.modifier'))
  WITH CHECK (rbac3_can('administration.valider') OR rbac3_can('administration.modifier'));

DROP POLICY IF EXISTS livsuivi_commandes_write ON public.livsuivi_commandes;
CREATE POLICY livsuivi_commandes_write ON public.livsuivi_commandes FOR ALL TO authenticated
  USING (rbac3_can('logistique.modifier')) WITH CHECK (rbac3_can('logistique.modifier'));

DROP POLICY IF EXISTS documents_write ON public.documents;
CREATE POLICY documents_write ON public.documents FOR ALL TO authenticated
  USING (rbac3_can('ventes.modifier') OR rbac3_can('administration.modifier'))
  WITH CHECK (rbac3_can('ventes.modifier') OR rbac3_can('administration.modifier'));