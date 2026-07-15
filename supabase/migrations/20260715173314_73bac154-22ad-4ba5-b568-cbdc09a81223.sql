
CREATE TABLE public.clients (
  client_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT,
  nom TEXT NOT NULL,
  type_client TEXT,
  representant TEXT,
  telephone TEXT,
  telephone2 TEXT,
  email TEXT,
  adresse TEXT,
  ville TEXT,
  commune TEXT,
  quartier TEXT,
  bp TEXT,
  pays TEXT DEFAULT 'Côte d''Ivoire',
  nif TEXT,
  regime_fiscal TEXT,
  contact_principal TEXT,
  plafond_credit NUMERIC DEFAULT 0,
  solde NUMERIC DEFAULT 0,
  remise_habituelle NUMERIC DEFAULT 0,
  mode_paiement TEXT DEFAULT 'comptant',
  delai_paiement INTEGER DEFAULT 0,
  categorie TEXT,
  secteur_activite TEXT,
  statut TEXT DEFAULT 'actif',
  motif_blocage TEXT,
  solde_points NUMERIC DEFAULT 0,
  notes TEXT,
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.clients TO authenticated;
GRANT ALL ON public.clients TO service_role;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated read clients" ON public.clients FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated write clients" ON public.clients FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_clients_nom ON public.clients (nom);
CREATE INDEX idx_clients_reference ON public.clients (reference);

CREATE TABLE public.produits (
  produit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT,
  titre TEXT NOT NULL,
  isbn TEXT,
  categorie TEXT,
  categorie_id UUID,
  niveau TEXT,
  niveau_ordre INTEGER,
  matiere TEXT,
  auteur TEXT,
  editeur TEXT,
  prix_vente NUMERIC NOT NULL DEFAULT 0,
  prix_achat NUMERIC NOT NULL DEFAULT 0,
  seuil_alerte INTEGER DEFAULT 10,
  pin_order INTEGER,
  cover_path TEXT,
  cover_thumb_path TEXT,
  cover_updated_at TIMESTAMPTZ,
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.produits TO authenticated;
GRANT ALL ON public.produits TO service_role;
ALTER TABLE public.produits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated read produits" ON public.produits FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated write produits" ON public.produits FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE TRIGGER update_produits_updated_at BEFORE UPDATE ON public.produits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_produits_titre ON public.produits (titre);
CREATE INDEX idx_produits_reference ON public.produits (reference);
