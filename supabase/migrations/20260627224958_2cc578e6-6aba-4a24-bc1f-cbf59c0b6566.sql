-- FOURNISSEURS
CREATE TABLE public.fournisseurs (
  fournisseur_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
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
CREATE POLICY "Staff view fournisseurs" ON public.fournisseurs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff insert fournisseurs" ON public.fournisseurs FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff update fournisseurs" ON public.fournisseurs FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Staff delete fournisseurs" ON public.fournisseurs FOR DELETE TO authenticated USING (true);
CREATE TRIGGER update_fournisseurs_updated_at BEFORE UPDATE ON public.fournisseurs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ACHATS
CREATE SEQUENCE IF NOT EXISTS public.achat_ref_seq;
CREATE TABLE public.achats (
  achat_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference text NOT NULL UNIQUE DEFAULT ('ACH-' || lpad(nextval('public.achat_ref_seq')::text, 5, '0')),
  fournisseur_id uuid REFERENCES public.fournisseurs(fournisseur_id) ON DELETE SET NULL,
  libelle text NOT NULL,
  montant numeric NOT NULL DEFAULT 0,
  statut text NOT NULL DEFAULT 'brouillon' CHECK (statut IN ('brouillon','commande','recu','paye','annule')),
  date_achat date NOT NULL DEFAULT CURRENT_DATE,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.achats TO authenticated;
GRANT ALL ON public.achats TO service_role;
ALTER TABLE public.achats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff view achats" ON public.achats FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff insert achats" ON public.achats FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff update achats" ON public.achats FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Staff delete achats" ON public.achats FOR DELETE TO authenticated USING (true);
CREATE TRIGGER update_achats_updated_at BEFORE UPDATE ON public.achats FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- EMPLOYES
CREATE SEQUENCE IF NOT EXISTS public.employe_ref_seq;
CREATE TABLE public.employes (
  employe_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  matricule text NOT NULL UNIQUE DEFAULT ('EMP-' || lpad(nextval('public.employe_ref_seq')::text, 5, '0')),
  nom_complet text NOT NULL,
  poste text,
  departement text NOT NULL DEFAULT 'autre',
  email text,
  telephone text,
  date_embauche date NOT NULL DEFAULT CURRENT_DATE,
  salaire numeric NOT NULL DEFAULT 0,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.employes TO authenticated;
GRANT ALL ON public.employes TO service_role;
ALTER TABLE public.employes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff view employes" ON public.employes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff insert employes" ON public.employes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff update employes" ON public.employes FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Staff delete employes" ON public.employes FOR DELETE TO authenticated USING (true);
CREATE TRIGGER update_employes_updated_at BEFORE UPDATE ON public.employes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- CONGES
CREATE TABLE public.conges (
  conge_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id uuid NOT NULL REFERENCES public.employes(employe_id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'annuel',
  date_debut date NOT NULL,
  date_fin date NOT NULL,
  motif text,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente','approuve','refuse')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.conges TO authenticated;
GRANT ALL ON public.conges TO service_role;
ALTER TABLE public.conges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff view conges" ON public.conges FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff insert conges" ON public.conges FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff update conges" ON public.conges FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Staff delete conges" ON public.conges FOR DELETE TO authenticated USING (true);
CREATE TRIGGER update_conges_updated_at BEFORE UPDATE ON public.conges FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();