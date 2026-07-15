CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id) $$;

CREATE OR REPLACE FUNCTION public.has_any_role(_user_id uuid, _roles public.app_role[])
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = ANY(_roles)) $$;

CREATE SEQUENCE IF NOT EXISTS public.factures_ref_seq START 1;
CREATE TABLE public.factures (
  facture_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('FAC-' || lpad(nextval('public.factures_ref_seq')::text, 5, '0')),
  client_id UUID REFERENCES public.clients(client_id) ON DELETE SET NULL,
  client_nom TEXT,
  commande_id UUID REFERENCES public.commandes(commande_id) ON DELETE SET NULL,
  date_facture DATE NOT NULL DEFAULT CURRENT_DATE,
  date_echeance DATE,
  montant_total NUMERIC NOT NULL DEFAULT 0,
  montant_paye NUMERIC NOT NULL DEFAULT 0,
  statut TEXT NOT NULL DEFAULT 'impayee',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.factures TO authenticated;
GRANT ALL ON public.factures TO service_role;
ALTER TABLE public.factures ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view factures" ON public.factures FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff can insert factures" ON public.factures FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff can update factures" ON public.factures FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff can delete factures" ON public.factures FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));
CREATE TRIGGER update_factures_updated_at BEFORE UPDATE ON public.factures FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE SEQUENCE IF NOT EXISTS public.paiements_ref_seq START 1;
CREATE TABLE public.paiements (
  paiement_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('PAY-' || lpad(nextval('public.paiements_ref_seq')::text, 5, '0')),
  facture_id UUID REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  client_nom TEXT,
  date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
  montant NUMERIC NOT NULL DEFAULT 0,
  mode_paiement TEXT NOT NULL DEFAULT 'especes',
  statut TEXT NOT NULL DEFAULT 'valide',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.paiements TO authenticated;
GRANT ALL ON public.paiements TO service_role;
ALTER TABLE public.paiements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view paiements" ON public.paiements FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff can insert paiements" ON public.paiements FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff can update paiements" ON public.paiements FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff can delete paiements" ON public.paiements FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));
CREATE TRIGGER update_paiements_updated_at BEFORE UPDATE ON public.paiements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE SEQUENCE IF NOT EXISTS public.proformas_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.livraisons_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.retours_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.missions_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.incidents_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.couts_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.colis_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.fne_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.inventaires_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.workflow_ref_seq START 1;

CREATE TABLE public.proformas (
  proforma_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('PRO-' || lpad(nextval('public.proformas_ref_seq')::text, 5, '0')),
  client_id UUID REFERENCES public.clients(client_id) ON DELETE SET NULL,
  client_nom TEXT,
  date_proforma DATE NOT NULL DEFAULT CURRENT_DATE,
  date_validite DATE,
  montant_total NUMERIC NOT NULL DEFAULT 0,
  statut TEXT NOT NULL DEFAULT 'en_attente',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.proforma_lignes (
  ligne_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  proforma_id uuid NOT NULL REFERENCES public.proformas(proforma_id) ON DELETE CASCADE,
  produit_id uuid,
  designation text NOT NULL,
  quantite integer NOT NULL DEFAULT 1,
  prix_unitaire numeric NOT NULL DEFAULT 0,
  total_ligne numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.proforma_lignes TO authenticated;
GRANT ALL ON public.proforma_lignes TO service_role;
ALTER TABLE public.proforma_lignes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff voir proforma_lignes" ON public.proforma_lignes FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff creer proforma_lignes" ON public.proforma_lignes FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff modifier proforma_lignes" ON public.proforma_lignes FOR UPDATE TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff supprimer proforma_lignes" ON public.proforma_lignes FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));
CREATE INDEX idx_proforma_lignes_proforma_id ON public.proforma_lignes(proforma_id);

CREATE TABLE public.livraisons (
  livraison_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('LIV-' || lpad(nextval('public.livraisons_ref_seq')::text, 5, '0')),
  commande_id UUID REFERENCES public.commandes(commande_id) ON DELETE SET NULL,
  client_nom TEXT,
  transporteur TEXT,
  adresse TEXT,
  date_livraison DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_preparation',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.retours (
  retour_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('RET-' || lpad(nextval('public.retours_ref_seq')::text, 5, '0')),
  client_nom TEXT, produit_nom TEXT, quantite INTEGER NOT NULL DEFAULT 1,
  motif TEXT, montant NUMERIC NOT NULL DEFAULT 0,
  date_retour DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_attente', notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.departements (
  departement_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  nom TEXT NOT NULL, responsable TEXT, description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.contrats (
  contrat_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT, type_contrat TEXT NOT NULL DEFAULT 'cdi',
  date_debut DATE NOT NULL DEFAULT CURRENT_DATE, date_fin DATE,
  salaire NUMERIC NOT NULL DEFAULT 0, statut TEXT NOT NULL DEFAULT 'actif', notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.absences (
  absence_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT, type_absence TEXT NOT NULL DEFAULT 'maladie',
  date_debut DATE NOT NULL DEFAULT CURRENT_DATE, date_fin DATE, motif TEXT,
  statut TEXT NOT NULL DEFAULT 'en_attente',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.missions (
  mission_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('MIS-' || lpad(nextval('public.missions_ref_seq')::text, 5, '0')),
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT, destination TEXT, objet TEXT,
  date_debut DATE NOT NULL DEFAULT CURRENT_DATE, date_fin DATE,
  budget NUMERIC NOT NULL DEFAULT 0, statut TEXT NOT NULL DEFAULT 'planifiee',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.evaluations (
  evaluation_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT, periode TEXT, note NUMERIC NOT NULL DEFAULT 0, commentaire TEXT,
  date_evaluation DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.bulletins_paie (
  bulletin_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT, periode TEXT NOT NULL,
  salaire_brut NUMERIC NOT NULL DEFAULT 0, retenues NUMERIC NOT NULL DEFAULT 0,
  salaire_net NUMERIC NOT NULL DEFAULT 0, statut TEXT NOT NULL DEFAULT 'genere',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.incidents (
  incident_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('INC-' || lpad(nextval('public.incidents_ref_seq')::text, 5, '0')),
  type_incident TEXT NOT NULL DEFAULT 'stock', gravite TEXT NOT NULL DEFAULT 'moyenne',
  description TEXT, date_incident DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'ouvert',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.vehicules (
  vehicule_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  immatriculation TEXT NOT NULL, marque TEXT, modele TEXT,
  type_vehicule TEXT NOT NULL DEFAULT 'camion', kilometrage INTEGER NOT NULL DEFAULT 0,
  statut TEXT NOT NULL DEFAULT 'disponible', notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.couts_logistiques (
  cout_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('CLO-' || lpad(nextval('public.couts_ref_seq')::text, 5, '0')),
  categorie TEXT NOT NULL DEFAULT 'carburant', libelle TEXT,
  montant NUMERIC NOT NULL DEFAULT 0, date_cout DATE NOT NULL DEFAULT CURRENT_DATE,
  vehicule_id UUID REFERENCES public.vehicules(vehicule_id) ON DELETE SET NULL, notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.colis (
  colis_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('COL-' || lpad(nextval('public.colis_ref_seq')::text, 5, '0')),
  destinataire TEXT, contenu TEXT, poids NUMERIC NOT NULL DEFAULT 0,
  transporteur TEXT, date_envoi DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_preparation', notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.notifications (
  notification_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  titre TEXT NOT NULL, message TEXT, type_notification TEXT NOT NULL DEFAULT 'info',
  lu BOOLEAN NOT NULL DEFAULT false, date_notification DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.fne_factures (
  fne_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('FNE-' || lpad(nextval('public.fne_ref_seq')::text, 5, '0')),
  facture_id UUID REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  client_nom TEXT, montant NUMERIC NOT NULL DEFAULT 0,
  date_emission DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_attente', code_dgi TEXT, notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.inventaires (
  inventaire_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('INV-' || lpad(nextval('public.inventaires_ref_seq')::text, 5, '0')),
  produit_nom TEXT, stock_theorique INTEGER NOT NULL DEFAULT 0,
  stock_compte INTEGER NOT NULL DEFAULT 0, ecart INTEGER NOT NULL DEFAULT 0,
  date_inventaire DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_cours', notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.documents (
  document_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  titre TEXT NOT NULL, type_document TEXT NOT NULL DEFAULT 'autre', description TEXT,
  date_document DATE NOT NULL DEFAULT CURRENT_DATE, statut TEXT NOT NULL DEFAULT 'actif',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.workflow_approvals (
  approval_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('WF-' || lpad(nextval('public.workflow_ref_seq')::text, 5, '0')),
  type_demande TEXT NOT NULL DEFAULT 'achat', demandeur TEXT, objet TEXT,
  montant NUMERIC NOT NULL DEFAULT 0, date_demande DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_attente', notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.parametres (
  parametre_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  cle TEXT NOT NULL UNIQUE, valeur TEXT, description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'proformas','livraisons','retours','departements','contrats','absences',
    'missions','evaluations','bulletins_paie','incidents','vehicules','couts_logistiques',
    'colis','notifications','fne_factures','inventaires','documents','workflow_approvals','parametres'
  ] LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated;', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role;', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE POLICY "Staff select %1$s" ON public.%1$I FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));', t);
    EXECUTE format('CREATE POLICY "Staff insert %1$s" ON public.%1$I FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));', t);
    EXECUTE format('CREATE POLICY "Staff update %1$s" ON public.%1$I FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));', t);
    EXECUTE format('CREATE POLICY "Staff delete %1$s" ON public.%1$I FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));', t);
    EXECUTE format('CREATE TRIGGER update_%1$s_updated_at BEFORE UPDATE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();', t);
  END LOOP;
END $$;

CREATE SEQUENCE IF NOT EXISTS public.ecriture_ref_seq;
CREATE TABLE public.ecritures_comptables (
  ecriture_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference text NOT NULL DEFAULT ('ECR-' || lpad(nextval('public.ecriture_ref_seq')::text, 5, '0')),
  date_ecriture date NOT NULL DEFAULT CURRENT_DATE,
  journal text NOT NULL DEFAULT 'OD', libelle text NOT NULL,
  source_type text, source_id uuid, lettrage text,
  montant_total numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.ecriture_lignes (
  ligne_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  ecriture_id uuid NOT NULL REFERENCES public.ecritures_comptables(ecriture_id) ON DELETE CASCADE,
  compte text NOT NULL, compte_libelle text NOT NULL,
  debit numeric NOT NULL DEFAULT 0, credit numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ecritures_comptables TO authenticated;
GRANT ALL ON public.ecritures_comptables TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ecriture_lignes TO authenticated;
GRANT ALL ON public.ecriture_lignes TO service_role;
ALTER TABLE public.ecritures_comptables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecriture_lignes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Finance ecritures" ON public.ecritures_comptables FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]));
CREATE POLICY "Finance ecriture_lignes" ON public.ecriture_lignes FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]));
CREATE INDEX idx_ecriture_lignes_ecriture_id ON public.ecriture_lignes(ecriture_id);
CREATE INDEX idx_ecritures_source ON public.ecritures_comptables(source_type, source_id);
CREATE TRIGGER trg_ecritures_updated_at BEFORE UPDATE ON public.ecritures_comptables FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.document_templates (
  template_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  label text NOT NULL, description text, config jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_templates TO authenticated;
GRANT ALL ON public.document_templates TO service_role;
ALTER TABLE public.document_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Own document templates" ON public.document_templates FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER update_document_templates_updated_at BEFORE UPDATE ON public.document_templates FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.document_template_prefs (
  user_id uuid NOT NULL PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  active_template_id text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_template_prefs TO authenticated;
GRANT ALL ON public.document_template_prefs TO service_role;
ALTER TABLE public.document_template_prefs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Own template pref" ON public.document_template_prefs FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER update_document_template_prefs_updated_at BEFORE UPDATE ON public.document_template_prefs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid, user_email text,
  action text NOT NULL, table_name text NOT NULL, record_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.audit_logs TO authenticated;
GRANT ALL ON public.audit_logs TO service_role;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Audit lisible direction" ON public.audit_logs FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]));
CREATE POLICY "Audit insertion staff" ON public.audit_logs FOR INSERT TO authenticated
  WITH CHECK (public.is_staff(auth.uid()));

-- Bootstrap premier super_admin lors du tout premier insert dans user_roles
CREATE OR REPLACE FUNCTION public.bootstrap_first_super_admin()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE role = 'super_admin') THEN
    NEW.role := 'super_admin';
  END IF;
  RETURN NEW;
END; $$;

DROP POLICY IF EXISTS "Users read own roles" ON public.user_roles;
CREATE POLICY "Users read own roles" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Super admin manage roles" ON public.user_roles FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'));