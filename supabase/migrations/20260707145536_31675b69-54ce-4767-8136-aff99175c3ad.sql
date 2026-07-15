
-- === colis_statut_historique : écritures explicitement réservées au trigger système ===
DROP POLICY IF EXISTS colis_statut_historique_no_insert ON public.colis_statut_historique;
DROP POLICY IF EXISTS colis_statut_historique_no_update ON public.colis_statut_historique;
DROP POLICY IF EXISTS colis_statut_historique_no_delete ON public.colis_statut_historique;

CREATE POLICY colis_statut_historique_no_insert
  ON public.colis_statut_historique FOR INSERT
  TO authenticated
  WITH CHECK (false);

CREATE POLICY colis_statut_historique_no_update
  ON public.colis_statut_historique FOR UPDATE
  TO authenticated
  USING (false) WITH CHECK (false);

CREATE POLICY colis_statut_historique_no_delete
  ON public.colis_statut_historique FOR DELETE
  TO authenticated
  USING (false);

COMMENT ON TABLE public.colis_statut_historique IS
  'Table d''audit en append-only. Alimentée exclusivement par le trigger SECURITY DEFINER sur colis. Aucune écriture directe autorisée depuis l''application.';

-- === documents : contrôle d'écriture différencié par type de document ===
DROP POLICY IF EXISTS "staff write documents" ON public.documents;
DROP POLICY IF EXISTS documents_write_operational ON public.documents;
DROP POLICY IF EXISTS documents_write_sensitive ON public.documents;

CREATE POLICY documents_write_operational
  ON public.documents
  FOR ALL
  TO authenticated
  USING (
    public.is_staff(auth.uid())
    AND type_document NOT IN ('finance','comptabilite','paie','rh','contrat','bulletin','fiscal')
  )
  WITH CHECK (
    public.is_staff(auth.uid())
    AND type_document NOT IN ('finance','comptabilite','paie','rh','contrat','bulletin','fiscal')
  );

CREATE POLICY documents_write_sensitive
  ON public.documents
  FOR ALL
  TO authenticated
  USING (
    type_document IN ('finance','comptabilite','paie','rh','contrat','bulletin','fiscal')
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[])
  )
  WITH CHECK (
    type_document IN ('finance','comptabilite','paie','rh','contrat','bulletin','fiscal')
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[])
  );
