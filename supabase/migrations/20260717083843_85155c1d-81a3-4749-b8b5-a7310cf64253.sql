
-- La vue "incidents" masquait la table incidents_stock. On supprime la vue et on renomme.
DROP VIEW IF EXISTS public.incidents CASCADE;
ALTER TABLE public.incidents_stock RENAME TO incidents;

ALTER TABLE public.incidents
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS motif text,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS responsable_id uuid,
  ADD COLUMN IF NOT EXISTS responsable_nom text,
  ADD COLUMN IF NOT EXISTS total_quantite numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_produits int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS exercice_id uuid,
  ADD COLUMN IF NOT EXISTS type_incident text;

UPDATE public.incidents SET type_incident = COALESCE(type_incident, "type") WHERE type_incident IS NULL;
ALTER TABLE public.incidents DROP COLUMN IF EXISTS "type";

DROP TRIGGER IF EXISTS trg_set_exercice_id ON public.incidents;
CREATE TRIGGER trg_set_exercice_id
  BEFORE INSERT ON public.incidents
  FOR EACH ROW EXECUTE FUNCTION public._set_exercice_id_before_insert();

CREATE TABLE IF NOT EXISTS public.incident_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL REFERENCES public.incidents(incident_id) ON DELETE CASCADE,
  produit_id uuid,
  reference_produit text,
  designation text NOT NULL DEFAULT '',
  quantite numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.incident_lignes TO authenticated;
GRANT ALL ON public.incident_lignes TO service_role;
ALTER TABLE public.incident_lignes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "incident_lignes_read_auth" ON public.incident_lignes;
CREATE POLICY "incident_lignes_read_auth" ON public.incident_lignes
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "incident_lignes_write_auth" ON public.incident_lignes;
CREATE POLICY "incident_lignes_write_auth" ON public.incident_lignes
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS idx_incident_lignes_incident_id ON public.incident_lignes(incident_id);

CREATE OR REPLACE FUNCTION public.creer_incident_stock(_payload jsonb)
 RETURNS SETOF public.incidents
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('INC','public.incidents','reference');
  v_l jsonb; v_qte numeric := 0; v_nb int := 0; v_nom text;
BEGIN
  v_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  INSERT INTO public.incidents(
    reference, numero, type_incident, gravite, description,
    date_incident, statut, motif, observations, depot_id,
    responsable_id, responsable_nom, total_quantite, nb_produits, created_by
  ) VALUES (
    v_ref, v_ref,
    COALESCE(_payload->>'type_incident', 'autre'),
    COALESCE(_payload->>'gravite', 'mineur'),
    _payload->>'description',
    COALESCE((_payload->>'date_incident')::timestamptz, now()),
    'declare',
    _payload->>'motif',
    _payload->>'observations',
    NULLIF(_payload->>'depot_id','')::uuid,
    auth.uid(), v_nom, 0, 0, auth.uid()
  ) RETURNING incident_id INTO v_id;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.incident_lignes(incident_id, produit_id, reference_produit, designation, quantite)
    VALUES (v_id, NULLIF(v_l->>'produit_id','')::uuid, v_l->>'reference_produit',
      COALESCE(v_l->>'designation',''), COALESCE((v_l->>'quantite')::numeric, 0));
    v_qte := v_qte + COALESCE((v_l->>'quantite')::numeric, 0);
    v_nb := v_nb + 1;
  END LOOP;
  UPDATE public.incidents SET total_quantite = v_qte, nb_produits = v_nb WHERE incident_id = v_id;
  RETURN QUERY SELECT * FROM public.incidents WHERE incident_id = v_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.annuler_incident(_incident_id uuid)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN UPDATE public.incidents SET statut='annule' WHERE incident_id = _incident_id; END; $function$;

-- MFA
CREATE TABLE IF NOT EXISTS public.two_fa_secrets (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  secret_chiffre text NOT NULL, active boolean NOT NULL DEFAULT false,
  codes_recuperation text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.two_fa_secrets TO authenticated;
GRANT ALL ON public.two_fa_secrets TO service_role;
ALTER TABLE public.two_fa_secrets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "two_fa_secrets_owner" ON public.two_fa_secrets;
CREATE POLICY "two_fa_secrets_owner" ON public.two_fa_secrets
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.mfa_backup_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_hash text NOT NULL, used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mfa_backup_codes_user ON public.mfa_backup_codes(user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mfa_backup_codes TO authenticated;
GRANT ALL ON public.mfa_backup_codes TO service_role;
ALTER TABLE public.mfa_backup_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "mfa_backup_codes_owner" ON public.mfa_backup_codes;
CREATE POLICY "mfa_backup_codes_owner" ON public.mfa_backup_codes
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.mfa_otp_attempts (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fail_count int NOT NULL DEFAULT 0, locked_until timestamptz,
  last_fail_at timestamptz, updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mfa_otp_attempts TO authenticated;
GRANT ALL ON public.mfa_otp_attempts TO service_role;
ALTER TABLE public.mfa_otp_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "mfa_otp_attempts_owner" ON public.mfa_otp_attempts;
CREATE POLICY "mfa_otp_attempts_owner" ON public.mfa_otp_attempts
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.mfa_session_validations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_token text NOT NULL, user_agent text,
  validated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '12 hours'),
  revoked_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_mfa_sessions_user ON public.mfa_session_validations(user_id);
CREATE INDEX IF NOT EXISTS idx_mfa_sessions_token ON public.mfa_session_validations(user_id, session_token);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mfa_session_validations TO authenticated;
GRANT ALL ON public.mfa_session_validations TO service_role;
ALTER TABLE public.mfa_session_validations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "mfa_sessions_owner" ON public.mfa_session_validations;
CREATE POLICY "mfa_sessions_owner" ON public.mfa_session_validations
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RH
CREATE TABLE IF NOT EXISTS public.employe_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employe_id uuid NOT NULL REFERENCES public.employes(employe_id) ON DELETE CASCADE,
  type_document text NOT NULL, nom text NOT NULL, storage_path text NOT NULL,
  mime_type text, taille_octets bigint, uploaded_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_employe_documents_employe ON public.employe_documents(employe_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.employe_documents TO authenticated;
GRANT ALL ON public.employe_documents TO service_role;
ALTER TABLE public.employe_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "employe_documents_auth" ON public.employe_documents;
CREATE POLICY "employe_documents_auth" ON public.employe_documents
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "employe_docs_auth_all" ON storage.objects;
CREATE POLICY "employe_docs_auth_all" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id IN ('employe-documents','employe-photos'))
  WITH CHECK (bucket_id IN ('employe-documents','employe-photos'));

-- COMPTABILITÉ
CREATE TABLE IF NOT EXISTS public.soldes_ouverture_clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(client_id) ON DELETE CASCADE,
  exercice_id uuid NOT NULL REFERENCES public.exercices_comptables(exercice_id) ON DELETE CASCADE,
  montant numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (client_id, exercice_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.soldes_ouverture_clients TO authenticated;
GRANT ALL ON public.soldes_ouverture_clients TO service_role;
ALTER TABLE public.soldes_ouverture_clients ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "soldes_ouv_clients_auth" ON public.soldes_ouverture_clients;
CREATE POLICY "soldes_ouv_clients_auth" ON public.soldes_ouverture_clients
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.soldes_ouverture_fournisseurs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fournisseur_id uuid NOT NULL REFERENCES public.fournisseurs(fournisseur_id) ON DELETE CASCADE,
  exercice_id uuid NOT NULL REFERENCES public.exercices_comptables(exercice_id) ON DELETE CASCADE,
  montant numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (fournisseur_id, exercice_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.soldes_ouverture_fournisseurs TO authenticated;
GRANT ALL ON public.soldes_ouverture_fournisseurs TO service_role;
ALTER TABLE public.soldes_ouverture_fournisseurs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "soldes_ouv_fourn_auth" ON public.soldes_ouverture_fournisseurs;
CREATE POLICY "soldes_ouv_fourn_auth" ON public.soldes_ouverture_fournisseurs
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.exercice_cloture_journal (
  journal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercice_source_id uuid REFERENCES public.exercices_comptables(exercice_id) ON DELETE SET NULL,
  exercice_cible_id uuid REFERENCES public.exercices_comptables(exercice_id) ON DELETE SET NULL,
  date_cloture timestamptz NOT NULL DEFAULT now(),
  cloture_par text,
  nb_clients_reportes int NOT NULL DEFAULT 0,
  montant_total_clients numeric NOT NULL DEFAULT 0,
  nb_fournisseurs_reportes int NOT NULL DEFAULT 0,
  montant_total_fournisseurs numeric NOT NULL DEFAULT 0,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.exercice_cloture_journal TO authenticated;
GRANT ALL ON public.exercice_cloture_journal TO service_role;
ALTER TABLE public.exercice_cloture_journal ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "exercice_cloture_journal_auth" ON public.exercice_cloture_journal;
CREATE POLICY "exercice_cloture_journal_auth" ON public.exercice_cloture_journal
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP VIEW IF EXISTS public.exercices CASCADE;
CREATE VIEW public.exercices WITH (security_invoker=on) AS
  SELECT exercice_id, libelle, date_debut, date_fin, statut, cloture_le,
         code, is_actif, created_at, updated_at
  FROM public.exercices_comptables;
GRANT SELECT ON public.exercices TO authenticated;

DROP VIEW IF EXISTS public.bons_retour CASCADE;
CREATE VIEW public.bons_retour WITH (security_invoker=on) AS
  SELECT retour_id AS bon_retour_id, reference, numero,
         client_id, client_nom, date_retour, statut, motif, notes,
         montant, total_quantite, nb_produits, exercice_id, created_at, updated_at
  FROM public.retours;
GRANT SELECT ON public.bons_retour TO authenticated;

-- LOGISTIQUE
CREATE TABLE IF NOT EXISTS public.couts_logistiques_audit (
  audit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournee_id uuid REFERENCES public.tournees(tournee_id) ON DELETE CASCADE,
  action text NOT NULL, actor_id uuid, actor_email text,
  commentaire text, avant jsonb, apres jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_couts_log_audit_tournee ON public.couts_logistiques_audit(tournee_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.couts_logistiques_audit TO authenticated;
GRANT ALL ON public.couts_logistiques_audit TO service_role;
ALTER TABLE public.couts_logistiques_audit ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "couts_log_audit_read_auth" ON public.couts_logistiques_audit;
CREATE POLICY "couts_log_audit_read_auth" ON public.couts_logistiques_audit
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "couts_log_audit_insert_auth" ON public.couts_logistiques_audit;
CREATE POLICY "couts_log_audit_insert_auth" ON public.couts_logistiques_audit
  FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
