-- Roles enum
CREATE TYPE public.app_role AS ENUM (
  'super_admin','directeur_general','comptable','directeur_commercial',
  'gestionnaire_stock','responsable_magasinier','secretariat','assistante','service_logistique'
);

-- Profiles
CREATE TABLE public.profiles (
  id UUID NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  nom_complet TEXT,
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles readable by authenticated" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE TABLE public.user_roles (
  id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own roles" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, nom_complet)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data ->> 'nom_complet');
  RETURN NEW;
END; $$;

CREATE TABLE public.clients (
  client_id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT NOT NULL DEFAULT ('CLI-' || substr(gen_random_uuid()::text,1,8)),
  nom TEXT NOT NULL,
  type_client TEXT NOT NULL DEFAULT 'autre',
  representant TEXT,
  telephone TEXT,
  email TEXT,
  adresse TEXT,
  ville TEXT,
  plafond_credit NUMERIC NOT NULL DEFAULT 0,
  solde NUMERIC NOT NULL DEFAULT 0,
  notes TEXT,
  actif BOOLEAN NOT NULL DEFAULT true,
  nif text,
  regime_fiscal text,
  contact_principal text,
  telephone2 text,
  quartier text,
  bp text,
  pays text DEFAULT 'Côte d''Ivoire',
  remise_habituelle numeric(5,2) DEFAULT 0,
  mode_paiement text DEFAULT 'comptant',
  delai_paiement integer DEFAULT 0,
  categorie text,
  secteur_activite text,
  statut text DEFAULT 'actif',
  motif_blocage text,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.clients TO authenticated;
GRANT ALL ON public.clients TO service_role;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Clients readable by authenticated" ON public.clients FOR SELECT TO authenticated USING (true);
CREATE POLICY "Clients insert by authenticated" ON public.clients FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Clients update by authenticated" ON public.clients FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Clients delete by authenticated" ON public.clients FOR DELETE TO authenticated USING (true);

CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE INDEX idx_clients_nom ON public.clients (nom);
CREATE INDEX idx_clients_type ON public.clients (type_client);
CREATE INDEX idx_clients_telephone ON public.clients(telephone);
CREATE INDEX idx_clients_statut ON public.clients(statut);
CREATE INDEX idx_clients_ville ON public.clients(ville);

CREATE SEQUENCE IF NOT EXISTS public.produit_ref_seq;
CREATE TABLE public.produits (
  produit_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT 'PRD-' || lpad(nextval('public.produit_ref_seq')::text, 5, '0'),
  titre TEXT NOT NULL,
  isbn TEXT,
  categorie TEXT NOT NULL DEFAULT 'manuel',
  niveau TEXT,
  matiere TEXT,
  auteur TEXT,
  editeur TEXT,
  prix_vente NUMERIC NOT NULL DEFAULT 0,
  prix_achat NUMERIC NOT NULL DEFAULT 0,
  stock INTEGER NOT NULL DEFAULT 0,
  seuil_alerte INTEGER NOT NULL DEFAULT 10,
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.produits TO authenticated;
GRANT ALL ON public.produits TO service_role;
ALTER TABLE public.produits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view produits" ON public.produits FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff can insert produits" ON public.produits FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update produits" ON public.produits FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Staff can delete produits" ON public.produits FOR DELETE TO authenticated USING (true);
CREATE TRIGGER update_produits_updated_at BEFORE UPDATE ON public.produits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE SEQUENCE IF NOT EXISTS commande_ref_seq START 1;
CREATE TABLE public.commandes (
  commande_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference text NOT NULL DEFAULT ('CMD-' || lpad(nextval('commande_ref_seq')::text, 5, '0')),
  client_id uuid REFERENCES public.clients(client_id) ON DELETE SET NULL,
  client_nom text,
  statut text NOT NULL DEFAULT 'brouillon',
  date_commande date NOT NULL DEFAULT current_date,
  remise numeric NOT NULL DEFAULT 0,
  montant_total numeric NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.commande_lignes (
  ligne_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  commande_id uuid NOT NULL REFERENCES public.commandes(commande_id) ON DELETE CASCADE,
  produit_id uuid REFERENCES public.produits(produit_id) ON DELETE SET NULL,
  designation text NOT NULL,
  quantite integer NOT NULL DEFAULT 1,
  prix_unitaire numeric NOT NULL DEFAULT 0,
  total_ligne numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.commandes TO authenticated;
GRANT ALL ON public.commandes TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.commande_lignes TO authenticated;
GRANT ALL ON public.commande_lignes TO service_role;
ALTER TABLE public.commandes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commande_lignes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view commandes" ON public.commandes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff can insert commandes" ON public.commandes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update commandes" ON public.commandes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Staff can delete commandes" ON public.commandes FOR DELETE TO authenticated USING (true);
CREATE POLICY "Staff can view lignes" ON public.commande_lignes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff can insert lignes" ON public.commande_lignes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update lignes" ON public.commande_lignes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Staff can delete lignes" ON public.commande_lignes FOR DELETE TO authenticated USING (true);
CREATE TRIGGER update_commandes_updated_at BEFORE UPDATE ON public.commandes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.stock_mouvements (
  mouvement_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  produit_id uuid NOT NULL REFERENCES public.produits(produit_id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'entree',
  quantite integer NOT NULL DEFAULT 0,
  stock_resultant integer NOT NULL DEFAULT 0,
  motif text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stock_mouvements TO authenticated;
GRANT ALL ON public.stock_mouvements TO service_role;
ALTER TABLE public.stock_mouvements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view mouvements" ON public.stock_mouvements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff can insert mouvements" ON public.stock_mouvements FOR INSERT TO authenticated WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.apply_stock_mouvement()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE current_stock integer; new_stock integer;
BEGIN
  SELECT stock INTO current_stock FROM public.produits WHERE produit_id = NEW.produit_id FOR UPDATE;
  IF current_stock IS NULL THEN RAISE EXCEPTION 'Produit introuvable'; END IF;
  IF NEW.type = 'entree' THEN new_stock := current_stock + NEW.quantite;
  ELSIF NEW.type = 'sortie' THEN new_stock := current_stock - NEW.quantite;
  ELSE new_stock := NEW.quantite; END IF;
  IF new_stock < 0 THEN new_stock := 0; END IF;
  UPDATE public.produits SET stock = new_stock, updated_at = now() WHERE produit_id = NEW.produit_id;
  NEW.stock_resultant := new_stock;
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_apply_stock_mouvement BEFORE INSERT ON public.stock_mouvements FOR EACH ROW EXECUTE FUNCTION public.apply_stock_mouvement();

CREATE SEQUENCE IF NOT EXISTS public.transaction_ref_seq;
CREATE TABLE public.transactions (
  transaction_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference text NOT NULL UNIQUE DEFAULT ('TRX-' || lpad(nextval('public.transaction_ref_seq')::text, 5, '0')),
  type text NOT NULL CHECK (type IN ('recette', 'depense')),
  categorie text NOT NULL DEFAULT 'autre',
  libelle text NOT NULL,
  montant numeric NOT NULL DEFAULT 0,
  date_transaction date NOT NULL DEFAULT CURRENT_DATE,
  mode_paiement text NOT NULL DEFAULT 'especes',
  notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transactions TO authenticated;
GRANT ALL ON public.transactions TO service_role;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Staff can view transactions" ON public.transactions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff can insert transactions" ON public.transactions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update transactions" ON public.transactions FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Staff can delete transactions" ON public.transactions FOR DELETE TO authenticated USING (true);
CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

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