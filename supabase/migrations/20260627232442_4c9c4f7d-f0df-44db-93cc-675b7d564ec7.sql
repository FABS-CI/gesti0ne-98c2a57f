-- Sequences
CREATE SEQUENCE IF NOT EXISTS public.proformas_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.livraisons_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.retours_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.missions_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.incidents_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.couts_ref_seq START 1;

-- PROFORMAS
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

-- LIVRAISONS
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

-- RETOURS
CREATE TABLE public.retours (
  retour_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('RET-' || lpad(nextval('public.retours_ref_seq')::text, 5, '0')),
  client_nom TEXT,
  produit_nom TEXT,
  quantite INTEGER NOT NULL DEFAULT 1,
  motif TEXT,
  montant NUMERIC NOT NULL DEFAULT 0,
  date_retour DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_attente',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- DEPARTEMENTS
CREATE TABLE public.departements (
  departement_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  nom TEXT NOT NULL,
  responsable TEXT,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CONTRATS
CREATE TABLE public.contrats (
  contrat_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT,
  type_contrat TEXT NOT NULL DEFAULT 'cdi',
  date_debut DATE NOT NULL DEFAULT CURRENT_DATE,
  date_fin DATE,
  salaire NUMERIC NOT NULL DEFAULT 0,
  statut TEXT NOT NULL DEFAULT 'actif',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ABSENCES
CREATE TABLE public.absences (
  absence_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT,
  type_absence TEXT NOT NULL DEFAULT 'maladie',
  date_debut DATE NOT NULL DEFAULT CURRENT_DATE,
  date_fin DATE,
  motif TEXT,
  statut TEXT NOT NULL DEFAULT 'en_attente',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- MISSIONS
CREATE TABLE public.missions (
  mission_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('MIS-' || lpad(nextval('public.missions_ref_seq')::text, 5, '0')),
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT,
  destination TEXT,
  objet TEXT,
  date_debut DATE NOT NULL DEFAULT CURRENT_DATE,
  date_fin DATE,
  budget NUMERIC NOT NULL DEFAULT 0,
  statut TEXT NOT NULL DEFAULT 'planifiee',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- EVALUATIONS
CREATE TABLE public.evaluations (
  evaluation_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT,
  periode TEXT,
  note NUMERIC NOT NULL DEFAULT 0,
  commentaire TEXT,
  date_evaluation DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- BULLETINS DE PAIE
CREATE TABLE public.bulletins_paie (
  bulletin_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  employe_nom TEXT,
  periode TEXT NOT NULL,
  salaire_brut NUMERIC NOT NULL DEFAULT 0,
  retenues NUMERIC NOT NULL DEFAULT 0,
  salaire_net NUMERIC NOT NULL DEFAULT 0,
  statut TEXT NOT NULL DEFAULT 'genere',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- INCIDENTS
CREATE TABLE public.incidents (
  incident_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('INC-' || lpad(nextval('public.incidents_ref_seq')::text, 5, '0')),
  type_incident TEXT NOT NULL DEFAULT 'stock',
  gravite TEXT NOT NULL DEFAULT 'moyenne',
  description TEXT,
  date_incident DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'ouvert',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- VEHICULES (FLOTTE)
CREATE TABLE public.vehicules (
  vehicule_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  immatriculation TEXT NOT NULL,
  marque TEXT,
  modele TEXT,
  type_vehicule TEXT NOT NULL DEFAULT 'camion',
  kilometrage INTEGER NOT NULL DEFAULT 0,
  statut TEXT NOT NULL DEFAULT 'disponible',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- COUTS LOGISTIQUES
CREATE TABLE public.couts_logistiques (
  cout_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('CLO-' || lpad(nextval('public.couts_ref_seq')::text, 5, '0')),
  categorie TEXT NOT NULL DEFAULT 'carburant',
  libelle TEXT,
  montant NUMERIC NOT NULL DEFAULT 0,
  date_cout DATE NOT NULL DEFAULT CURRENT_DATE,
  vehicule_id UUID REFERENCES public.vehicules(vehicule_id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- GRANTS + RLS + POLICIES + TRIGGERS
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'proformas','livraisons','retours','departements','contrats','absences',
    'missions','evaluations','bulletins_paie','incidents','vehicules','couts_logistiques'
  ] LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated;', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role;', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE POLICY "Staff select %1$s" ON public.%1$I FOR SELECT TO authenticated USING (true);', t);
    EXECUTE format('CREATE POLICY "Staff insert %1$s" ON public.%1$I FOR INSERT TO authenticated WITH CHECK (true);', t);
    EXECUTE format('CREATE POLICY "Staff update %1$s" ON public.%1$I FOR UPDATE TO authenticated USING (true) WITH CHECK (true);', t);
    EXECUTE format('CREATE POLICY "Staff delete %1$s" ON public.%1$I FOR DELETE TO authenticated USING (true);', t);
    EXECUTE format('CREATE TRIGGER update_%1$s_updated_at BEFORE UPDATE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();', t);
  END LOOP;
END $$;