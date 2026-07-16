
-- ============================================================
-- Comprehensive repair: missing tables/views/columns/FKs
-- ============================================================

-- 1) EXERCICES_COMPTABLES: add code, is_actif
ALTER TABLE public.exercices_comptables
  ADD COLUMN IF NOT EXISTS code text,
  ADD COLUMN IF NOT EXISTS is_actif boolean NOT NULL DEFAULT false;
UPDATE public.exercices_comptables SET code = COALESCE(code, libelle);

-- Backfill: if none is_actif, activate the newest open one
DO $$
DECLARE v_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.exercices_comptables WHERE is_actif) THEN
    SELECT exercice_id INTO v_id FROM public.exercices_comptables
      WHERE statut='ouvert' ORDER BY date_debut DESC LIMIT 1;
    IF v_id IS NOT NULL THEN
      UPDATE public.exercices_comptables SET is_actif=true WHERE exercice_id=v_id;
    END IF;
  END IF;
END $$;

-- Seed a default exercice if the table is empty so ExerciceContext works
INSERT INTO public.exercices_comptables (libelle, code, date_debut, date_fin, statut, is_actif)
SELECT '2026', '2026', '2026-01-01', '2026-12-31', 'ouvert', true
WHERE NOT EXISTS (SELECT 1 FROM public.exercices_comptables);

-- View alias `exercices` (readable by authenticated + anon so the app never 404s)
CREATE OR REPLACE VIEW public.exercices AS
  SELECT exercice_id, code, libelle, date_debut, date_fin, statut, is_actif, cloture_le, created_at, updated_at
  FROM public.exercices_comptables;
GRANT SELECT ON public.exercices TO authenticated, anon;

-- 2) DOCUMENT_SETTINGS (per user)
CREATE TABLE IF NOT EXISTS public.document_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  selected_template text NOT NULL DEFAULT 'classique',
  template_per_type jsonb NOT NULL DEFAULT '{}'::jsonb,
  logo_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_settings TO authenticated;
GRANT ALL ON public.document_settings TO service_role;
ALTER TABLE public.document_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own_doc_settings" ON public.document_settings;
CREATE POLICY "own_doc_settings" ON public.document_settings FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 3) INCIDENT_ALERTS
CREATE TABLE IF NOT EXISTS public.incident_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'info',
  message text,
  source text,
  resolved boolean NOT NULL DEFAULT false,
  resolved_at timestamptz,
  resolved_by uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.incident_alerts TO authenticated;
GRANT ALL ON public.incident_alerts TO service_role;
ALTER TABLE public.incident_alerts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_read_incident_alerts" ON public.incident_alerts;
CREATE POLICY "auth_read_incident_alerts" ON public.incident_alerts FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_write_incident_alerts" ON public.incident_alerts;
CREATE POLICY "auth_write_incident_alerts" ON public.incident_alerts
  TO authenticated USING (true) WITH CHECK (true);

-- 4) USER_ACTION_STATS
CREATE TABLE IF NOT EXISTS public.user_action_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_key text NOT NULL,
  module text,
  label text,
  icon text,
  href text,
  usage_count int NOT NULL DEFAULT 0,
  last_used_at timestamptz,
  pinned boolean NOT NULL DEFAULT false,
  hidden boolean NOT NULL DEFAULT false,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, action_key)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_action_stats TO authenticated;
GRANT ALL ON public.user_action_stats TO service_role;
ALTER TABLE public.user_action_stats ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own_action_stats" ON public.user_action_stats;
CREATE POLICY "own_action_stats" ON public.user_action_stats FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 5) LOGIN_HISTORY
CREATE TABLE IF NOT EXISTS public.login_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  ip text,
  user_agent text,
  success boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.login_history TO authenticated;
GRANT ALL ON public.login_history TO service_role;
ALTER TABLE public.login_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own_login_history" ON public.login_history;
CREATE POLICY "own_login_history" ON public.login_history FOR SELECT
  TO authenticated USING (auth.uid() = user_id OR public.has_role(auth.uid(),'super_admin'));
DROP POLICY IF EXISTS "insert_login_history" ON public.login_history;
CREATE POLICY "insert_login_history" ON public.login_history FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

-- 6) WORKFLOW_APPROVALS + WORKFLOWS_DEFINITIONS
CREATE TABLE IF NOT EXISTS public.workflows_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  libelle text NOT NULL,
  description text,
  actif boolean NOT NULL DEFAULT true,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workflows_definitions TO authenticated;
GRANT ALL ON public.workflows_definitions TO service_role;
ALTER TABLE public.workflows_definitions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_all_workflows_def" ON public.workflows_definitions;
CREATE POLICY "auth_all_workflows_def" ON public.workflows_definitions
  TO authenticated USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.workflow_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_code text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  reference text,
  statut text NOT NULL DEFAULT 'en_attente',
  demandeur_id uuid,
  demandeur_nom text,
  approbateur_id uuid,
  approbateur_nom text,
  commentaire text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workflow_approvals TO authenticated;
GRANT ALL ON public.workflow_approvals TO service_role;
ALTER TABLE public.workflow_approvals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_all_wf_appr" ON public.workflow_approvals;
CREATE POLICY "auth_all_wf_appr" ON public.workflow_approvals
  TO authenticated USING (true) WITH CHECK (true);

-- 7) PERF_QUERY_LOG + V_RPC_ERRORS_RECENT
CREATE TABLE IF NOT EXISTS public.perf_query_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query_key text,
  route text,
  duration_ms int,
  status text,
  error text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.perf_query_log TO authenticated;
GRANT ALL ON public.perf_query_log TO service_role;
ALTER TABLE public.perf_query_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_perf_log" ON public.perf_query_log;
CREATE POLICY "auth_perf_log" ON public.perf_query_log
  TO authenticated USING (true) WITH CHECK (true);

CREATE OR REPLACE VIEW public.v_rpc_errors_recent AS
  SELECT id, query_key, route, duration_ms, status, error, metadata, created_at
  FROM public.perf_query_log
  WHERE status = 'error' AND created_at > now() - interval '7 days';
GRANT SELECT ON public.v_rpc_errors_recent TO authenticated;

-- 8) FNE_SETTINGS + FNE_FACTURES + FNE_LOGS
CREATE TABLE IF NOT EXISTS public.fne_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cle_api text,
  identifiant text,
  environnement text NOT NULL DEFAULT 'test',
  actif boolean NOT NULL DEFAULT false,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fne_settings TO authenticated;
GRANT ALL ON public.fne_settings TO service_role;
ALTER TABLE public.fne_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_fne_settings" ON public.fne_settings;
CREATE POLICY "auth_fne_settings" ON public.fne_settings
  TO authenticated USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.fne_factures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facture_id uuid,
  reference text,
  statut text NOT NULL DEFAULT 'en_attente',
  fne_ref text,
  qr_code text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fne_factures TO authenticated;
GRANT ALL ON public.fne_factures TO service_role;
ALTER TABLE public.fne_factures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_fne_factures" ON public.fne_factures;
CREATE POLICY "auth_fne_factures" ON public.fne_factures
  TO authenticated USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.fne_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facture_id uuid,
  niveau text NOT NULL DEFAULT 'info',
  message text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.fne_logs TO authenticated;
GRANT ALL ON public.fne_logs TO service_role;
ALTER TABLE public.fne_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_fne_logs" ON public.fne_logs;
CREATE POLICY "auth_fne_logs" ON public.fne_logs
  TO authenticated USING (true) WITH CHECK (true);

-- 9) DOCUMENT_TEMPLATES + DOCUMENT_TEMPLATE_PREFS + DOCUMENTS
CREATE TABLE IF NOT EXISTS public.document_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  libelle text NOT NULL,
  description text,
  contenu jsonb NOT NULL DEFAULT '{}'::jsonb,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_templates TO authenticated;
GRANT ALL ON public.document_templates TO service_role;
ALTER TABLE public.document_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_doc_templates" ON public.document_templates;
CREATE POLICY "auth_doc_templates" ON public.document_templates
  TO authenticated USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.document_template_prefs (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  prefs jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_template_prefs TO authenticated;
GRANT ALL ON public.document_template_prefs TO service_role;
ALTER TABLE public.document_template_prefs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own_doc_tpl_prefs" ON public.document_template_prefs;
CREATE POLICY "own_doc_tpl_prefs" ON public.document_template_prefs FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  titre text NOT NULL,
  type text,
  entity_type text,
  entity_id uuid,
  url text,
  mime_type text,
  taille_octets bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents TO authenticated;
GRANT ALL ON public.documents TO service_role;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_documents" ON public.documents;
CREATE POLICY "auth_documents" ON public.documents
  TO authenticated USING (true) WITH CHECK (true);

-- 10) CATEGORIES_PRODUITS
CREATE TABLE IF NOT EXISTS public.categories_produits (
  categorie_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  libelle text NOT NULL,
  description text,
  parent_id uuid REFERENCES public.categories_produits(categorie_id) ON DELETE SET NULL,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.categories_produits TO authenticated;
GRANT ALL ON public.categories_produits TO service_role;
ALTER TABLE public.categories_produits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_categ_prod" ON public.categories_produits;
CREATE POLICY "auth_categ_prod" ON public.categories_produits
  TO authenticated USING (true) WITH CHECK (true);

-- 11) HISTORIQUE_ENVOIS
CREATE TABLE IF NOT EXISTS public.historique_envois (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  destinataire text,
  entity_type text,
  entity_id uuid,
  reference text,
  statut text NOT NULL DEFAULT 'envoye',
  message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  sent_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.historique_envois TO authenticated;
GRANT ALL ON public.historique_envois TO service_role;
ALTER TABLE public.historique_envois ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_hist_envois" ON public.historique_envois;
CREATE POLICY "auth_hist_envois" ON public.historique_envois
  TO authenticated USING (true) WITH CHECK (true);

-- 12) VIEW ALIASES for renamed tables
CREATE OR REPLACE VIEW public.audit_events AS SELECT * FROM public.audit_logs;
GRANT SELECT ON public.audit_events TO authenticated;

CREATE OR REPLACE VIEW public.paie_rubriques AS SELECT * FROM public.rubriques_paie;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.paie_rubriques TO authenticated;

CREATE OR REPLACE VIEW public.paie_parametres AS SELECT * FROM public.parametres_paie;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.paie_parametres TO authenticated;

CREATE OR REPLACE VIEW public.parametres AS SELECT * FROM public.parametres_systeme;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.parametres TO authenticated;

CREATE OR REPLACE VIEW public.bons_retour AS SELECT * FROM public.retours;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bons_retour TO authenticated;

CREATE OR REPLACE VIEW public.incidents AS SELECT * FROM public.incidents_stock;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.incidents TO authenticated;

-- 13) ADD MISSING COLUMNS on existing tables (fixes 400s)

-- absences: statut, employe_nom
ALTER TABLE public.absences
  ADD COLUMN IF NOT EXISTS statut text NOT NULL DEFAULT 'valide',
  ADD COLUMN IF NOT EXISTS employe_nom text;

-- contrats: employe_nom
ALTER TABLE public.contrats
  ADD COLUMN IF NOT EXISTS employe_nom text;

-- evaluations: employe_nom (config references it)
ALTER TABLE public.evaluations
  ADD COLUMN IF NOT EXISTS employe_nom text;

-- vehicules: statut, dates
ALTER TABLE public.vehicules
  ADD COLUMN IF NOT EXISTS statut text NOT NULL DEFAULT 'actif',
  ADD COLUMN IF NOT EXISTS date_prochain_entretien date,
  ADD COLUMN IF NOT EXISTS date_expiration_assurance date,
  ADD COLUMN IF NOT EXISTS date_expiration_visite_technique date;

-- fonctions: departement_id
ALTER TABLE public.fonctions
  ADD COLUMN IF NOT EXISTS departement_id uuid REFERENCES public.departements(departement_id) ON DELETE SET NULL;

-- departements: nom
ALTER TABLE public.departements
  ADD COLUMN IF NOT EXISTS nom text;
UPDATE public.departements SET nom = COALESCE(nom, libelle) WHERE nom IS NULL;

-- ecritures_comptables: journal, lettrage
ALTER TABLE public.ecritures_comptables
  ADD COLUMN IF NOT EXISTS journal text,
  ADD COLUMN IF NOT EXISTS lettrage text;

-- ecriture_lignes: compte, compte_libelle
ALTER TABLE public.ecriture_lignes
  ADD COLUMN IF NOT EXISTS compte text,
  ADD COLUMN IF NOT EXISTS compte_libelle text;
UPDATE public.ecriture_lignes SET compte = COALESCE(compte, numero_compte) WHERE compte IS NULL;

-- Ensure FK ecriture_lignes -> ecritures_comptables (for PostgREST embed)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name='ecriture_lignes' AND constraint_type='FOREIGN KEY'
      AND constraint_name='ecriture_lignes_ecriture_id_fkey'
  ) THEN
    ALTER TABLE public.ecriture_lignes
      ADD CONSTRAINT ecriture_lignes_ecriture_id_fkey
      FOREIGN KEY (ecriture_id) REFERENCES public.ecritures_comptables(ecriture_id) ON DELETE CASCADE;
  END IF;
END $$;

-- produits: stock (nullable numeric — no derived value; filter returns empty)
ALTER TABLE public.produits
  ADD COLUMN IF NOT EXISTS stock numeric;

-- transferts: FKs to depots so PostgREST embed works
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name='transferts_depot_source_id_fkey') THEN
    ALTER TABLE public.transferts
      ADD CONSTRAINT transferts_depot_source_id_fkey
      FOREIGN KEY (depot_source_id) REFERENCES public.depots(depot_id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name='transferts_depot_destination_id_fkey') THEN
    ALTER TABLE public.transferts
      ADD CONSTRAINT transferts_depot_destination_id_fkey
      FOREIGN KEY (depot_destination_id) REFERENCES public.depots(depot_id) ON DELETE SET NULL;
  END IF;
END $$;

-- tournees FK to vehicules
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name='tournees_vehicule_id_fkey') THEN
    ALTER TABLE public.tournees
      ADD CONSTRAINT tournees_vehicule_id_fkey
      FOREIGN KEY (vehicule_id) REFERENCES public.vehicules(vehicule_id) ON DELETE SET NULL;
  END IF;
END $$;

-- livsuivi_commandes FKs
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name='livsuivi_commandes_commande_id_fkey') THEN
    ALTER TABLE public.livsuivi_commandes
      ADD CONSTRAINT livsuivi_commandes_commande_id_fkey
      FOREIGN KEY (commande_id) REFERENCES public.commandes(commande_id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name='livsuivi_commandes_tournee_id_fkey') THEN
    ALTER TABLE public.livsuivi_commandes
      ADD CONSTRAINT livsuivi_commandes_tournee_id_fkey
      FOREIGN KEY (tournee_id) REFERENCES public.tournees(tournee_id) ON DELETE SET NULL;
  END IF;
END $$;

-- 14) Reload PostgREST schema cache to pick up new tables/views/FKs/columns
NOTIFY pgrst, 'reload schema';
