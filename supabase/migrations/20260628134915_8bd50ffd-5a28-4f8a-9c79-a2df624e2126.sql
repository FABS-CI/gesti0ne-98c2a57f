
CREATE TABLE public.categories_produits (
  categorie_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  parent_id UUID REFERENCES public.categories_produits(categorie_id) ON DELETE SET NULL,
  description TEXT,
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.categories_produits TO authenticated;
GRANT ALL ON public.categories_produits TO service_role;
ALTER TABLE public.categories_produits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read categories_produits" ON public.categories_produits FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff write categories_produits" ON public.categories_produits FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER trg_categories_produits_updated BEFORE UPDATE ON public.categories_produits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_categories_produits_parent ON public.categories_produits(parent_id);

CREATE TABLE public.fonctions (
  fonction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  libelle TEXT NOT NULL,
  departement_id UUID REFERENCES public.departements(departement_id) ON DELETE SET NULL,
  description TEXT,
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fonctions TO authenticated;
GRANT ALL ON public.fonctions TO service_role;
ALTER TABLE public.fonctions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read fonctions" ON public.fonctions FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff write fonctions" ON public.fonctions FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER trg_fonctions_updated BEFORE UPDATE ON public.fonctions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.bons_livraison (
  bl_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT NOT NULL UNIQUE DEFAULT ('BL-' || to_char(now(),'YYYYMMDD-HH24MISS') || '-' || substr(gen_random_uuid()::text,1,4)),
  commande_id UUID REFERENCES public.commandes(commande_id) ON DELETE SET NULL,
  client_id UUID REFERENCES public.clients(client_id) ON DELETE SET NULL,
  date_emission DATE NOT NULL DEFAULT CURRENT_DATE,
  date_livraison DATE,
  statut TEXT NOT NULL DEFAULT 'brouillon',
  transporteur TEXT,
  adresse_livraison TEXT,
  signataire TEXT,
  notes TEXT,
  montant_total NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bons_livraison TO authenticated;
GRANT ALL ON public.bons_livraison TO service_role;
ALTER TABLE public.bons_livraison ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read bons_livraison" ON public.bons_livraison FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff write bons_livraison" ON public.bons_livraison FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER trg_bl_updated BEFORE UPDATE ON public.bons_livraison FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_bl_commande ON public.bons_livraison(commande_id);
CREATE INDEX idx_bl_client ON public.bons_livraison(client_id);

CREATE TABLE public.bons_retour (
  br_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT NOT NULL UNIQUE DEFAULT ('BR-' || to_char(now(),'YYYYMMDD-HH24MISS') || '-' || substr(gen_random_uuid()::text,1,4)),
  client_id UUID REFERENCES public.clients(client_id) ON DELETE SET NULL,
  facture_id UUID REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  date_retour DATE NOT NULL DEFAULT CURRENT_DATE,
  motif TEXT,
  statut TEXT NOT NULL DEFAULT 'en_attente',
  montant NUMERIC(14,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bons_retour TO authenticated;
GRANT ALL ON public.bons_retour TO service_role;
ALTER TABLE public.bons_retour ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read bons_retour" ON public.bons_retour FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff write bons_retour" ON public.bons_retour FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER trg_br_updated BEFORE UPDATE ON public.bons_retour FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.ordres_colisage (
  ordre_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT NOT NULL UNIQUE DEFAULT ('OC-' || to_char(now(),'YYYYMMDD-HH24MISS') || '-' || substr(gen_random_uuid()::text,1,4)),
  commande_id UUID REFERENCES public.commandes(commande_id) ON DELETE SET NULL,
  nb_colis INTEGER NOT NULL DEFAULT 0,
  poids_total NUMERIC(10,3) NOT NULL DEFAULT 0,
  dimensions TEXT,
  statut TEXT NOT NULL DEFAULT 'en_preparation',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ordres_colisage TO authenticated;
GRANT ALL ON public.ordres_colisage TO service_role;
ALTER TABLE public.ordres_colisage ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read ordres_colisage" ON public.ordres_colisage FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff write ordres_colisage" ON public.ordres_colisage FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER trg_oc_updated BEFORE UPDATE ON public.ordres_colisage FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.expeditions (
  expedition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT NOT NULL UNIQUE DEFAULT ('EXP-' || to_char(now(),'YYYYMMDD-HH24MISS') || '-' || substr(gen_random_uuid()::text,1,4)),
  ordre_colisage_id UUID REFERENCES public.ordres_colisage(ordre_id) ON DELETE SET NULL,
  bl_id UUID REFERENCES public.bons_livraison(bl_id) ON DELETE SET NULL,
  transporteur TEXT,
  tracking TEXT,
  date_depart DATE,
  date_arrivee_prevue DATE,
  date_arrivee_reelle DATE,
  cout NUMERIC(14,2) NOT NULL DEFAULT 0,
  statut TEXT NOT NULL DEFAULT 'planifiee',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expeditions TO authenticated;
GRANT ALL ON public.expeditions TO service_role;
ALTER TABLE public.expeditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read expeditions" ON public.expeditions FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff write expeditions" ON public.expeditions FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER trg_exp_updated BEFORE UPDATE ON public.expeditions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.historique_envois (
  envoi_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  canal TEXT NOT NULL,
  destinataire TEXT NOT NULL,
  sujet TEXT,
  contenu TEXT,
  document_type TEXT,
  document_id UUID,
  statut TEXT NOT NULL DEFAULT 'envoye',
  erreur TEXT,
  envoye_par UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.historique_envois TO authenticated;
GRANT ALL ON public.historique_envois TO service_role;
ALTER TABLE public.historique_envois ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read historique_envois" ON public.historique_envois FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff write historique_envois" ON public.historique_envois FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE INDEX idx_envois_doc ON public.historique_envois(document_type, document_id);

CREATE TABLE public.fne_logs (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fne_facture_id UUID REFERENCES public.fne_factures(fne_id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  payload JSONB,
  response JSONB,
  statut TEXT NOT NULL DEFAULT 'en_cours',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fne_logs TO authenticated;
GRANT ALL ON public.fne_logs TO service_role;
ALTER TABLE public.fne_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read fne_logs" ON public.fne_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff write fne_logs" ON public.fne_logs FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE INDEX idx_fne_logs_facture ON public.fne_logs(fne_facture_id);

CREATE TABLE public.fne_settings (
  setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cle TEXT NOT NULL UNIQUE,
  valeur TEXT,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fne_settings TO authenticated;
GRANT ALL ON public.fne_settings TO service_role;
ALTER TABLE public.fne_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read fne_settings" ON public.fne_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin write fne_settings" ON public.fne_settings FOR ALL TO authenticated USING (public.has_role(auth.uid(),'super_admin') OR public.has_role(auth.uid(),'directeur_general')) WITH CHECK (public.has_role(auth.uid(),'super_admin') OR public.has_role(auth.uid(),'directeur_general'));
CREATE TRIGGER trg_fne_settings_updated BEFORE UPDATE ON public.fne_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.two_fa_secrets (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  secret_chiffre TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT false,
  codes_recuperation TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.two_fa_secrets TO authenticated;
GRANT ALL ON public.two_fa_secrets TO service_role;
ALTER TABLE public.two_fa_secrets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own 2fa" ON public.two_fa_secrets FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER trg_2fa_updated BEFORE UPDATE ON public.two_fa_secrets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.workflows_definitions (
  workflow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  entite_type TEXT NOT NULL,
  description TEXT,
  etapes JSONB NOT NULL DEFAULT '[]'::jsonb,
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workflows_definitions TO authenticated;
GRANT ALL ON public.workflows_definitions TO service_role;
ALTER TABLE public.workflows_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth read workflows_def" ON public.workflows_definitions FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin write workflows_def" ON public.workflows_definitions FOR ALL TO authenticated USING (public.has_role(auth.uid(),'super_admin') OR public.has_role(auth.uid(),'directeur_general')) WITH CHECK (public.has_role(auth.uid(),'super_admin') OR public.has_role(auth.uid(),'directeur_general'));
CREATE TRIGGER trg_wfd_updated BEFORE UPDATE ON public.workflows_definitions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.produits ADD COLUMN IF NOT EXISTS categorie_id UUID REFERENCES public.categories_produits(categorie_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_produits_categorie ON public.produits(categorie_id);

ALTER TABLE public.employes ADD COLUMN IF NOT EXISTS fonction_id UUID REFERENCES public.fonctions(fonction_id) ON DELETE SET NULL;
