
-- factures
CREATE TABLE IF NOT EXISTS public.factures (
  facture_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text NOT NULL DEFAULT '',
  client_id uuid,
  client_nom text,
  commande_id uuid,
  exercice_id uuid,
  date_facture date NOT NULL DEFAULT CURRENT_DATE,
  date_echeance date,
  montant_total numeric NOT NULL DEFAULT 0,
  montant_paye numeric NOT NULL DEFAULT 0,
  statut text NOT NULL DEFAULT 'impayee',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.factures TO authenticated;
GRANT ALL ON public.factures TO service_role;
ALTER TABLE public.factures ENABLE ROW LEVEL SECURITY;
CREATE POLICY "factures read auth" ON public.factures FOR SELECT TO authenticated USING (true);
CREATE POLICY "factures write auth" ON public.factures FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE TRIGGER trg_factures_updated BEFORE UPDATE ON public.factures FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_factures_client ON public.factures(client_id);
CREATE INDEX idx_factures_commande ON public.factures(commande_id);
CREATE INDEX idx_factures_statut ON public.factures(statut);
CREATE INDEX idx_factures_date ON public.factures(date_facture);

-- paiements
CREATE TABLE IF NOT EXISTS public.paiements (
  paiement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text NOT NULL DEFAULT '',
  facture_id uuid REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  client_nom text,
  date_paiement date NOT NULL DEFAULT CURRENT_DATE,
  montant numeric NOT NULL DEFAULT 0,
  mode_paiement text NOT NULL DEFAULT 'espece',
  statut text NOT NULL DEFAULT 'valide',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.paiements TO authenticated;
GRANT ALL ON public.paiements TO service_role;
ALTER TABLE public.paiements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "paiements read auth" ON public.paiements FOR SELECT TO authenticated USING (true);
CREATE POLICY "paiements write auth" ON public.paiements FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE TRIGGER trg_paiements_updated BEFORE UPDATE ON public.paiements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_paiements_facture ON public.paiements(facture_id);
CREATE INDEX idx_paiements_date ON public.paiements(date_paiement);

-- paiement_annulations_audit
CREATE TABLE IF NOT EXISTS public.paiement_annulations_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  paiement_id uuid NOT NULL,
  facture_id uuid,
  annule_par uuid,
  annule_le timestamptz NOT NULL DEFAULT now(),
  raison text NOT NULL DEFAULT '',
  notes text,
  montant_annule numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.paiement_annulations_audit TO authenticated;
GRANT ALL ON public.paiement_annulations_audit TO service_role;
ALTER TABLE public.paiement_annulations_audit ENABLE ROW LEVEL SECURITY;
CREATE POLICY "paa read auth" ON public.paiement_annulations_audit FOR SELECT TO authenticated USING (true);
CREATE POLICY "paa write auth" ON public.paiement_annulations_audit FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- fournisseurs
CREATE TABLE IF NOT EXISTS public.fournisseurs (
  fournisseur_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  raison_sociale text NOT NULL,
  contact text,
  email text,
  telephone text,
  adresse text,
  ville text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fournisseurs TO authenticated;
GRANT ALL ON public.fournisseurs TO service_role;
ALTER TABLE public.fournisseurs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "fournisseurs read auth" ON public.fournisseurs FOR SELECT TO authenticated USING (true);
CREATE POLICY "fournisseurs write auth" ON public.fournisseurs FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE TRIGGER trg_fournisseurs_updated BEFORE UPDATE ON public.fournisseurs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- achats
CREATE TABLE IF NOT EXISTS public.achats (
  achat_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text NOT NULL DEFAULT '',
  fournisseur_id uuid REFERENCES public.fournisseurs(fournisseur_id) ON DELETE SET NULL,
  depot_id uuid,
  libelle text NOT NULL DEFAULT '',
  montant numeric NOT NULL DEFAULT 0,
  statut text NOT NULL DEFAULT 'brouillon',
  date_achat date NOT NULL DEFAULT CURRENT_DATE,
  notes text,
  reference_fournisseur text,
  created_by uuid,
  created_by_nom text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.achats TO authenticated;
GRANT ALL ON public.achats TO service_role;
ALTER TABLE public.achats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "achats read auth" ON public.achats FOR SELECT TO authenticated USING (true);
CREATE POLICY "achats write auth" ON public.achats FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE TRIGGER trg_achats_updated BEFORE UPDATE ON public.achats FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_achats_fournisseur ON public.achats(fournisseur_id);
CREATE INDEX idx_achats_date ON public.achats(date_achat);

-- achat_lignes
CREATE TABLE IF NOT EXISTS public.achat_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  achat_id uuid NOT NULL REFERENCES public.achats(achat_id) ON DELETE CASCADE,
  produit_id uuid,
  reference_produit text,
  designation text NOT NULL DEFAULT '',
  quantite numeric NOT NULL DEFAULT 0,
  prix_unitaire numeric NOT NULL DEFAULT 0,
  total_ligne numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.achat_lignes TO authenticated;
GRANT ALL ON public.achat_lignes TO service_role;
ALTER TABLE public.achat_lignes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "achat_lignes read auth" ON public.achat_lignes FOR SELECT TO authenticated USING (true);
CREATE POLICY "achat_lignes write auth" ON public.achat_lignes FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE INDEX idx_achat_lignes_achat ON public.achat_lignes(achat_id);

-- employes
CREATE TABLE IF NOT EXISTS public.employes (
  employe_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  matricule text NOT NULL DEFAULT '',
  nom_complet text NOT NULL,
  poste text,
  departement text NOT NULL DEFAULT 'autre',
  email text,
  telephone text,
  date_embauche date NOT NULL DEFAULT CURRENT_DATE,
  salaire numeric NOT NULL DEFAULT 0,
  actif boolean NOT NULL DEFAULT true,
  deleted_at timestamptz,
  prenoms text,
  sexe text,
  date_naissance date,
  lieu_naissance text,
  nationalite text,
  situation_matrimoniale text,
  photo_url text,
  numero_cni text,
  numero_cnps text,
  numero_securite_sociale text,
  adresse text,
  commune text,
  ville text,
  pays text,
  telephone_secondaire text,
  fonction_id uuid,
  service text,
  responsable_hierarchique_id uuid,
  type_contrat text,
  date_fin_contrat date,
  statut_employe text,
  temps_travail text,
  categorie text,
  echelon text,
  site_affectation text,
  primes jsonb,
  indemnites jsonb,
  avantages jsonb,
  mode_paiement text,
  banque text,
  numero_compte text,
  devise text,
  centre_cout text,
  niveau_etudes text,
  diplomes jsonb,
  competences jsonb,
  certifications jsonb,
  contact_urgence_nom text,
  contact_urgence_telephone text,
  contact_urgence_lien text,
  observations text,
  user_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.employes TO authenticated;
GRANT ALL ON public.employes TO service_role;
ALTER TABLE public.employes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "employes read auth" ON public.employes FOR SELECT TO authenticated USING (true);
CREATE POLICY "employes write auth" ON public.employes FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE TRIGGER trg_employes_updated BEFORE UPDATE ON public.employes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- conges
CREATE TABLE IF NOT EXISTS public.conges (
  conge_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employe_id uuid NOT NULL REFERENCES public.employes(employe_id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'annuel',
  date_debut date NOT NULL,
  date_fin date NOT NULL,
  motif text,
  statut text NOT NULL DEFAULT 'en_attente',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.conges TO authenticated;
GRANT ALL ON public.conges TO service_role;
ALTER TABLE public.conges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "conges read auth" ON public.conges FOR SELECT TO authenticated USING (true);
CREATE POLICY "conges write auth" ON public.conges FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE TRIGGER trg_conges_updated BEFORE UPDATE ON public.conges FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_conges_employe ON public.conges(employe_id);

-- stock_mouvements
CREATE TABLE IF NOT EXISTS public.stock_mouvements (
  mouvement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  produit_id uuid NOT NULL,
  depot_id uuid,
  type text NOT NULL,
  quantite numeric NOT NULL DEFAULT 0,
  quantite_entree numeric NOT NULL DEFAULT 0,
  quantite_sortie numeric NOT NULL DEFAULT 0,
  stock_resultant numeric NOT NULL DEFAULT 0,
  motif text,
  origine text,
  document_id uuid,
  document_reference text,
  document_table text,
  user_id uuid,
  user_nom text,
  observation text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stock_mouvements TO authenticated;
GRANT ALL ON public.stock_mouvements TO service_role;
ALTER TABLE public.stock_mouvements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "stock_mvt read auth" ON public.stock_mouvements FOR SELECT TO authenticated USING (true);
CREATE POLICY "stock_mvt write auth" ON public.stock_mouvements FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE INDEX idx_stock_mvt_produit ON public.stock_mouvements(produit_id);
CREATE INDEX idx_stock_mvt_date ON public.stock_mouvements(created_at);
