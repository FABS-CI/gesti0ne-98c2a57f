
-- paie_parametres
DROP POLICY IF EXISTS paie_parametres_auth_all ON public.paie_parametres;
CREATE POLICY paie_parametres_select ON public.paie_parametres
  FOR SELECT TO authenticated USING (true);
CREATE POLICY paie_parametres_write ON public.paie_parametres
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]));

-- paie_rubriques
DROP POLICY IF EXISTS paie_rubriques_auth_all ON public.paie_rubriques;
CREATE POLICY paie_rubriques_select ON public.paie_rubriques
  FOR SELECT TO authenticated USING (true);
CREATE POLICY paie_rubriques_write ON public.paie_rubriques
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]));

-- colis_statut_historique : restreint la lecture aux rôles opérationnels
DROP POLICY IF EXISTS "Authentifies peuvent lire historique colis" ON public.colis_statut_historique;
CREATE POLICY colis_statut_historique_select ON public.colis_statut_historique
  FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','directeur_commercial','service_logistique','responsable_magasinier','gestionnaire_stock','secretariat']::app_role[]));

-- tournees : lecture large, écritures restreintes
DROP POLICY IF EXISTS "Authenticated can insert tournees" ON public.tournees;
DROP POLICY IF EXISTS "Authenticated can update tournees" ON public.tournees;
DROP POLICY IF EXISTS "Authenticated can delete tournees" ON public.tournees;
CREATE POLICY tournees_insert ON public.tournees
  FOR INSERT TO authenticated
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique','directeur_commercial','responsable_magasinier','gestionnaire_stock']::app_role[]));
CREATE POLICY tournees_update ON public.tournees
  FOR UPDATE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique','directeur_commercial','responsable_magasinier','gestionnaire_stock']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique','directeur_commercial','responsable_magasinier','gestionnaire_stock']::app_role[]));
CREATE POLICY tournees_delete ON public.tournees
  FOR DELETE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]));
