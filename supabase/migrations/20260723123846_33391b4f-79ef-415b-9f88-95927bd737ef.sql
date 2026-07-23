
-- ============================================================================
-- 1) EXTENSION workflow_approvals
-- ============================================================================
ALTER TABLE public.workflow_approvals
  ADD COLUMN IF NOT EXISTS module text,
  ADD COLUMN IF NOT EXISTS niveau_urgence text NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS sla_deadline timestamptz,
  ADD COLUMN IF NOT EXISTS version_no integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS historique jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS pieces_jointes jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS simulation_financiere jsonb,
  ADD COLUMN IF NOT EXISTS decision_details jsonb,
  ADD COLUMN IF NOT EXISTS motif_refus text;

UPDATE public.workflow_approvals SET module = workflow_code WHERE module IS NULL;

CREATE INDEX IF NOT EXISTS idx_wf_appr_module_statut ON public.workflow_approvals(module, statut);
CREATE INDEX IF NOT EXISTS idx_wf_appr_entity ON public.workflow_approvals(entity_type, entity_id);

-- ============================================================================
-- 2) EXTENSION retours
-- ============================================================================
ALTER TABLE public.retours
  ADD COLUMN IF NOT EXISTS receptionne_par uuid,
  ADD COLUMN IF NOT EXISTS receptionne_par_nom text,
  ADD COLUMN IF NOT EXISTS receptionne_at timestamptz,
  ADD COLUMN IF NOT EXISTS valide_compta_par uuid,
  ADD COLUMN IF NOT EXISTS valide_compta_par_nom text,
  ADD COLUMN IF NOT EXISTS valide_compta_at timestamptz,
  ADD COLUMN IF NOT EXISTS motif_refus_magasin text,
  ADD COLUMN IF NOT EXISTS motif_refus_compta text,
  ADD COLUMN IF NOT EXISTS version_no integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS workflow_approval_id uuid;

UPDATE public.retours SET statut = CASE statut
  WHEN 'accepte' THEN 'cloture'
  WHEN 'accepté' THEN 'cloture'
  WHEN 'en_cours' THEN 'attente_reception'
  WHEN 'refuse' THEN 'refus_magasin'
  WHEN 'refusé' THEN 'refus_magasin'
  WHEN 'annule' THEN 'annule'
  ELSE COALESCE(statut, 'demande_creee')
END;

ALTER TABLE public.retours DROP CONSTRAINT IF EXISTS retours_statut_check;
ALTER TABLE public.retours ADD CONSTRAINT retours_statut_check
  CHECK (statut IN (
    'demande_creee','attente_reception','receptionne',
    'attente_validation_compta','valide_compta','cloture',
    'refus_magasin','refus_compta','annule'
  ));

-- ============================================================================
-- 3) EXTENSION retour_lignes
-- ============================================================================
ALTER TABLE public.retour_lignes
  ADD COLUMN IF NOT EXISTS quantite_demandee numeric,
  ADD COLUMN IF NOT EXISTS quantite_recue numeric,
  ADD COLUMN IF NOT EXISTS etat_reception text,
  ADD COLUMN IF NOT EXISTS commentaire_reception text;

UPDATE public.retour_lignes SET quantite_demandee = quantite WHERE quantite_demandee IS NULL;

ALTER TABLE public.retour_lignes DROP CONSTRAINT IF EXISTS retour_lignes_etat_check;
ALTER TABLE public.retour_lignes ADD CONSTRAINT retour_lignes_etat_check
  CHECK (etat_reception IS NULL OR etat_reception IN ('conforme','endommage','refuse'));

-- ============================================================================
-- 4) Module + Ressource RBAC pour approbations
-- ============================================================================
INSERT INTO public.rbac2_modules (code, domain_code, label, sort)
VALUES ('approbations', 'administration', 'Centre d''Approbation', 50)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.rbac2_resources (code, module_code, label, kind, sort)
VALUES ('approbations:approbations', 'approbations', 'Approbations', 'screen', 100)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- 5) PERMISSIONS RBAC v2 (avec resource_code + action)
-- ============================================================================
INSERT INTO public.rbac2_permissions (code, resource_code, action, label, description) VALUES
  ('retours.receptionner',       'retours:retours',            'receptionner',   'Réceptionner un retour',            'Gestionnaire stock : réception physique'),
  ('retours.refuser_magasin',    'retours:retours',            'refuser',        'Refuser un retour (magasin)',       'Refus physique au magasin'),
  ('retours.valider_compta',     'retours:retours',            'valider_compta', 'Valider financièrement un retour',  'Comptable : impact financier'),
  ('retours.refuser_compta',     'retours:retours',            'refuser_compta', 'Refuser un retour (comptable)',     'Comptable : refus financier'),
  ('retours.forcer_cloture',     'retours:retours',            'forcer',         'Forcer la clôture d''un retour',    'Super Admin uniquement'),
  ('approbations.voir',          'approbations:approbations',  'voir',           'Voir le Centre d''Approbation',     'Accès au tableau de bord'),
  ('approbations.valider',       'approbations:approbations',  'valider',        'Valider une approbation',           'Décision positive'),
  ('approbations.refuser',       'approbations:approbations',  'refuser',        'Refuser une approbation',           'Décision négative'),
  ('approbations.forcer',        'approbations:approbations',  'forcer',         'Forcer une décision',               'Super Admin'),
  ('approbations.rouvrir',       'approbations:approbations',  'rouvrir',        'Rouvrir une approbation',           'Super Admin')
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- 6) Affectation aux rôles (rbac2_role_perms)
-- ============================================================================
INSERT INTO public.rbac2_role_perms (role_code, perm_code, granted) VALUES
  ('commercial',             'approbations.voir',        true),
  ('gestionnaire_stock',     'retours.receptionner',     true),
  ('gestionnaire_stock',     'retours.refuser_magasin',  true),
  ('gestionnaire_stock',     'approbations.voir',        true),
  ('responsable_magasinier', 'retours.receptionner',     true),
  ('responsable_magasinier', 'retours.refuser_magasin',  true),
  ('responsable_magasinier', 'approbations.voir',        true),
  ('comptable',              'retours.valider_compta',   true),
  ('comptable',              'retours.refuser_compta',   true),
  ('comptable',              'approbations.voir',        true),
  ('comptable',              'approbations.valider',     true),
  ('comptable',              'approbations.refuser',     true),
  ('assistante_comptable',   'approbations.voir',        true),
  ('super_admin',            'retours.receptionner',     true),
  ('super_admin',            'retours.refuser_magasin',  true),
  ('super_admin',            'retours.valider_compta',   true),
  ('super_admin',            'retours.refuser_compta',   true),
  ('super_admin',            'retours.forcer_cloture',   true),
  ('super_admin',            'approbations.voir',        true),
  ('super_admin',            'approbations.valider',     true),
  ('super_admin',            'approbations.refuser',     true),
  ('super_admin',            'approbations.forcer',      true),
  ('super_admin',            'approbations.rouvrir',     true),
  ('admin',                  'approbations.voir',        true),
  ('admin',                  'approbations.valider',     true),
  ('admin',                  'approbations.refuser',     true)
ON CONFLICT (role_code, perm_code) DO NOTHING;

-- ============================================================================
-- 7) Contrainte SoD : commercial + comptable interdit
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_check_sod_roles()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_has_conflict boolean;
BEGIN
  IF NEW.role_code IN ('commercial','comptable') THEN
    SELECT EXISTS(
      SELECT 1 FROM public.rbac2_user_roles ur
      WHERE ur.user_id = NEW.user_id
        AND ur.role_code IN ('commercial','comptable')
        AND ur.role_code <> NEW.role_code
    ) INTO v_has_conflict;
    IF v_has_conflict THEN
      RAISE EXCEPTION 'SOD_VIOLATION: un utilisateur ne peut pas cumuler les rôles Commercial et Comptable'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS trg_sod_check ON public.rbac2_user_roles;
CREATE TRIGGER trg_sod_check
  BEFORE INSERT OR UPDATE ON public.rbac2_user_roles
  FOR EACH ROW EXECUTE FUNCTION public.trg_check_sod_roles();

-- ============================================================================
-- 8) Migration rétroactive des retours existants
-- ============================================================================
INSERT INTO public.workflow_approvals (
  workflow_code, module, entity_type, entity_id, reference,
  statut, demandeur_id, demandeur_nom, decided_at, metadata
)
SELECT
  'retour_valider_compta','retours','retour', r.retour_id,
  COALESCE(r.numero, r.reference),
  CASE WHEN r.statut = 'cloture' THEN 'valide' ELSE 'en_attente' END,
  r.created_by, r.created_by_nom,
  CASE WHEN r.statut = 'cloture' THEN COALESCE(r.updated_at, r.created_at) END,
  jsonb_build_object('migration_auto', true, 'ancien_statut', r.statut)
FROM public.retours r
WHERE NOT EXISTS (
  SELECT 1 FROM public.workflow_approvals wa
  WHERE wa.entity_type='retour' AND wa.entity_id = r.retour_id
);

UPDATE public.retours r
SET workflow_approval_id = wa.id
FROM public.workflow_approvals wa
WHERE wa.entity_type='retour' AND wa.entity_id=r.retour_id AND r.workflow_approval_id IS NULL;

-- ============================================================================
-- 9) RLS resserrée
-- ============================================================================
DROP POLICY IF EXISTS auth_read_retours ON public.retours;
DROP POLICY IF EXISTS auth_write_retours ON public.retours;
DROP POLICY IF EXISTS retours_select ON public.retours;
DROP POLICY IF EXISTS retours_insert ON public.retours;
DROP POLICY IF EXISTS retours_update ON public.retours;
DROP POLICY IF EXISTS retours_delete ON public.retours;

CREATE POLICY retours_select ON public.retours FOR SELECT TO authenticated USING (true);
CREATE POLICY retours_insert ON public.retours FOR INSERT TO authenticated
  WITH CHECK (public.has_permission(auth.uid(),'retours.creer'));
CREATE POLICY retours_update ON public.retours FOR UPDATE TO authenticated
  USING (
    public.has_permission(auth.uid(),'retours.creer')
    OR public.has_permission(auth.uid(),'retours.receptionner')
    OR public.has_permission(auth.uid(),'retours.valider_compta')
    OR public.has_permission(auth.uid(),'retours.annuler')
    OR public.has_permission(auth.uid(),'retours.forcer_cloture')
  );
CREATE POLICY retours_delete ON public.retours FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(),'super_admin'::app_role));

DROP POLICY IF EXISTS auth_all_wf_appr ON public.workflow_approvals;
DROP POLICY IF EXISTS wf_appr_select ON public.workflow_approvals;
DROP POLICY IF EXISTS wf_appr_write ON public.workflow_approvals;

CREATE POLICY wf_appr_select ON public.workflow_approvals FOR SELECT TO authenticated
  USING (public.has_permission(auth.uid(),'approbations.voir'));
CREATE POLICY wf_appr_all ON public.workflow_approvals FOR ALL TO authenticated
  USING (
    public.has_permission(auth.uid(),'approbations.voir')
    OR public.has_permission(auth.uid(),'approbations.valider')
    OR public.has_permission(auth.uid(),'approbations.refuser')
    OR public.has_permission(auth.uid(),'approbations.forcer')
  )
  WITH CHECK (
    public.has_permission(auth.uid(),'approbations.valider')
    OR public.has_permission(auth.uid(),'approbations.refuser')
    OR public.has_permission(auth.uid(),'approbations.forcer')
    OR public.has_permission(auth.uid(),'retours.creer')
    OR public.has_permission(auth.uid(),'retours.receptionner')
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.workflow_approvals TO authenticated;
GRANT ALL ON public.workflow_approvals TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.retours TO authenticated;
GRANT ALL ON public.retours TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.retour_lignes TO authenticated;
GRANT ALL ON public.retour_lignes TO service_role;
