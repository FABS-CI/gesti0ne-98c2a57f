
-- Helper pour appliquer GRANTS / RLS / policies / trigger updated_at de manière uniforme
CREATE OR REPLACE FUNCTION public._erp_setup_table(_t text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', _t);
  EXECUTE format('GRANT ALL ON public.%I TO service_role', _t);
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', _t);
  EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (true)', 'auth_read_'||_t, _t);
  EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (true) WITH CHECK (true)', 'auth_write_'||_t, _t);
  EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column()', 'update_'||_t||'_updated_at', _t);
END; $$;

-- =========================================================
-- MODULE COMMERCIAL
-- =========================================================
CREATE TABLE public.proformas (
  proforma_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  client_id uuid,
  client_nom text,
  commande_id uuid,
  date_proforma date DEFAULT CURRENT_DATE,
  date_validite date,
  montant_total numeric DEFAULT 0,
  statut text DEFAULT 'brouillon',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('proformas');

CREATE TABLE public.proforma_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proforma_id uuid NOT NULL REFERENCES public.proformas(proforma_id) ON DELETE CASCADE,
  produit_id uuid,
  reference_produit text,
  designation text,
  quantite numeric DEFAULT 0,
  prix_unitaire numeric DEFAULT 0,
  total_ligne numeric DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('proforma_lignes');

CREATE TABLE public.retours (
  retour_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  client_id uuid,
  client_nom text,
  commande_id uuid,
  facture_id uuid,
  date_retour date DEFAULT CURRENT_DATE,
  motif text,
  statut text DEFAULT 'en_cours',
  montant numeric DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('retours');

CREATE TABLE public.retour_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retour_id uuid NOT NULL REFERENCES public.retours(retour_id) ON DELETE CASCADE,
  produit_id uuid,
  designation text,
  quantite numeric DEFAULT 0,
  prix_unitaire numeric DEFAULT 0,
  total_ligne numeric DEFAULT 0,
  motif text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('retour_lignes');

CREATE TABLE public.specimens (
  specimen_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  produit_id uuid,
  client_id uuid,
  client_nom text,
  date_envoi date DEFAULT CURRENT_DATE,
  quantite numeric DEFAULT 0,
  statut text DEFAULT 'envoye',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('specimens');

CREATE TABLE public.crm_interactions (
  interaction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid,
  type text,
  canal text,
  sujet text,
  resume text,
  agent_email text,
  date_interaction timestamptz DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('crm_interactions');

-- =========================================================
-- MODULE STOCK & LOGISTIQUE
-- =========================================================
CREATE TABLE public.depots (
  depot_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text,
  nom text NOT NULL,
  adresse text,
  ville text,
  responsable text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('depots');

CREATE TABLE public.approvisionnements (
  approvisionnement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  fournisseur_id uuid,
  depot_id uuid,
  date_appro date DEFAULT CURRENT_DATE,
  montant numeric DEFAULT 0,
  statut text DEFAULT 'en_cours',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('approvisionnements');

CREATE TABLE public.approvisionnement_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  approvisionnement_id uuid NOT NULL REFERENCES public.approvisionnements(approvisionnement_id) ON DELETE CASCADE,
  produit_id uuid,
  designation text,
  quantite numeric DEFAULT 0,
  prix_unitaire numeric DEFAULT 0,
  total_ligne numeric DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('approvisionnement_lignes');

CREATE TABLE public.preparateurs (
  preparateur_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom_complet text NOT NULL,
  email text,
  telephone text,
  role text DEFAULT 'preparateur',
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('preparateurs');

CREATE TABLE public.colisages (
  colisage_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  commande_id uuid,
  preparateur_id uuid,
  responsable_id uuid,
  date_colisage timestamptz DEFAULT now(),
  nb_colis integer DEFAULT 0,
  poids_total numeric DEFAULT 0,
  statut text DEFAULT 'en_cours',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('colisages');

CREATE TABLE public.livreurs (
  livreur_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  matricule text,
  nom_complet text NOT NULL,
  telephone text,
  permis text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('livreurs');

CREATE TABLE public.vehicules (
  vehicule_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  immatriculation text,
  marque text,
  modele text,
  type text,
  capacite numeric,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('vehicules');

CREATE TABLE public.tournees (
  tournee_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  livreur_id uuid,
  vehicule_id uuid,
  date_tournee date DEFAULT CURRENT_DATE,
  statut text DEFAULT 'planifiee',
  nb_livraisons integer DEFAULT 0,
  distance_km numeric DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('tournees');

CREATE TABLE public.livraisons (
  livraison_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  commande_id uuid,
  colisage_id uuid,
  livreur_id uuid,
  tournee_id uuid,
  date_livraison timestamptz,
  statut text DEFAULT 'planifiee',
  adresse_livraison text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('livraisons');

CREATE TABLE public.bons_livraison (
  bon_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  livraison_id uuid,
  commande_id uuid,
  client_nom text,
  date_bon date DEFAULT CURRENT_DATE,
  montant numeric DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('bons_livraison');

CREATE TABLE public.inventaires (
  inventaire_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  depot_id uuid,
  date_inventaire date DEFAULT CURRENT_DATE,
  statut text DEFAULT 'en_cours',
  ecart_total numeric DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('inventaires');

CREATE TABLE public.inventaire_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventaire_id uuid NOT NULL REFERENCES public.inventaires(inventaire_id) ON DELETE CASCADE,
  produit_id uuid,
  designation text,
  quantite_theorique numeric DEFAULT 0,
  quantite_physique numeric DEFAULT 0,
  ecart numeric DEFAULT 0,
  observation text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('inventaire_lignes');

CREATE TABLE public.incidents_stock (
  incident_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  produit_id uuid,
  depot_id uuid,
  type text,
  gravite text,
  description text,
  date_incident timestamptz DEFAULT now(),
  statut text DEFAULT 'ouvert',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('incidents_stock');

CREATE TABLE public.alertes_stock (
  alerte_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  produit_id uuid,
  depot_id uuid,
  seuil numeric DEFAULT 0,
  quantite_actuelle numeric DEFAULT 0,
  niveau text,
  message text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('alertes_stock');

CREATE TABLE public.audit_stock (
  audit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  produit_id uuid,
  depot_id uuid,
  quantite_avant numeric,
  quantite_apres numeric,
  motif text,
  user_email text,
  date_audit timestamptz DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('audit_stock');

CREATE TABLE public.transferts (
  transfert_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  depot_source_id uuid,
  depot_destination_id uuid,
  date_transfert date DEFAULT CURRENT_DATE,
  statut text DEFAULT 'en_cours',
  motif text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('transferts');

CREATE TABLE public.transfert_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfert_id uuid NOT NULL REFERENCES public.transferts(transfert_id) ON DELETE CASCADE,
  produit_id uuid,
  designation text,
  quantite numeric DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('transfert_lignes');

-- =========================================================
-- MODULE FINANCES
-- =========================================================
CREATE TABLE public.fne_declarations (
  fne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  facture_id uuid,
  date_declaration timestamptz DEFAULT now(),
  numero_fne text,
  qr_code text,
  statut text DEFAULT 'en_attente',
  message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('fne_declarations');

CREATE TABLE public.couts_logistiques (
  cout_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  type text,
  libelle text,
  montant numeric DEFAULT 0,
  date_cout date DEFAULT CURRENT_DATE,
  tournee_id uuid,
  livraison_id uuid,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('couts_logistiques');

-- =========================================================
-- MODULE COMPTABILITE
-- =========================================================
CREATE TABLE public.exercices_comptables (
  exercice_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  libelle text NOT NULL,
  date_debut date NOT NULL,
  date_fin date NOT NULL,
  statut text NOT NULL DEFAULT 'ouvert',
  cloture_le timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('exercices_comptables');

CREATE TABLE public.plan_comptable (
  compte_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero text UNIQUE NOT NULL,
  libelle text NOT NULL,
  classe integer,
  type text,
  parent_numero text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('plan_comptable');

CREATE TABLE public.journaux_comptables (
  journal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  libelle text NOT NULL,
  type text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('journaux_comptables');

CREATE TABLE public.ecritures_comptables (
  ecriture_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  exercice_id uuid,
  journal_id uuid,
  date_ecriture date DEFAULT CURRENT_DATE,
  libelle text,
  montant numeric DEFAULT 0,
  statut text DEFAULT 'brouillon',
  piece_ref text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('ecritures_comptables');

CREATE TABLE public.ecriture_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ecriture_id uuid NOT NULL REFERENCES public.ecritures_comptables(ecriture_id) ON DELETE CASCADE,
  compte_id uuid,
  numero_compte text,
  libelle text,
  debit numeric DEFAULT 0,
  credit numeric DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('ecriture_lignes');

-- =========================================================
-- MODULE RH
-- =========================================================
CREATE TABLE public.departements (
  departement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text,
  libelle text NOT NULL,
  responsable text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('departements');

CREATE TABLE public.fonctions (
  fonction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text,
  libelle text NOT NULL,
  description text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('fonctions');

CREATE TABLE public.contrats (
  contrat_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employe_id uuid,
  type text,
  date_debut date,
  date_fin date,
  salaire numeric DEFAULT 0,
  statut text DEFAULT 'actif',
  document_url text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('contrats');

CREATE TABLE public.absences (
  absence_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employe_id uuid,
  type text,
  date_debut date,
  date_fin date,
  motif text,
  justifie boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('absences');

CREATE TABLE public.missions (
  mission_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  employe_id uuid,
  libelle text,
  destination text,
  date_debut date,
  date_fin date,
  montant numeric DEFAULT 0,
  statut text DEFAULT 'planifiee',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('missions');

CREATE TABLE public.evaluations (
  evaluation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employe_id uuid,
  periode text,
  note numeric,
  commentaire text,
  evaluateur text,
  date_evaluation date DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('evaluations');

-- =========================================================
-- MODULE PAIE
-- =========================================================
CREATE TABLE public.rubriques_paie (
  rubrique_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text,
  libelle text NOT NULL,
  type text,
  formule text,
  taux numeric,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('rubriques_paie');

CREATE TABLE public.parametres_paie (
  parametre_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cle text UNIQUE NOT NULL,
  valeur text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('parametres_paie');

CREATE TABLE public.bulletins_paie (
  bulletin_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  employe_id uuid,
  periode text,
  date_bulletin date DEFAULT CURRENT_DATE,
  salaire_brut numeric DEFAULT 0,
  salaire_net numeric DEFAULT 0,
  cotisations numeric DEFAULT 0,
  statut text DEFAULT 'brouillon',
  pdf_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('bulletins_paie');

CREATE TABLE public.bulletin_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bulletin_id uuid NOT NULL REFERENCES public.bulletins_paie(bulletin_id) ON DELETE CASCADE,
  rubrique_id uuid,
  code text,
  libelle text,
  base numeric DEFAULT 0,
  taux numeric DEFAULT 0,
  montant numeric DEFAULT 0,
  type text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('bulletin_lignes');

CREATE TABLE public.declarations_paie (
  declaration_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text,
  periode text,
  type text,
  montant numeric DEFAULT 0,
  date_declaration date DEFAULT CURRENT_DATE,
  statut text DEFAULT 'brouillon',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('declarations_paie');

-- =========================================================
-- MODULE ADMINISTRATION
-- =========================================================
CREATE TABLE public.parametres_systeme (
  parametre_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cle text UNIQUE NOT NULL,
  valeur text,
  categorie text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('parametres_systeme');

CREATE TABLE public.parametres_entreprise (
  parametre_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cle text UNIQUE NOT NULL,
  valeur text,
  categorie text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
SELECT public._erp_setup_table('parametres_entreprise');

-- Suppression du helper (usage ponctuel de migration)
DROP FUNCTION public._erp_setup_table(text);
