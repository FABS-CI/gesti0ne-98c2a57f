
-- Table commandes
CREATE TABLE public.commandes (
  commande_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT,
  numero TEXT,
  client_id UUID,
  client_nom TEXT,
  etablissement TEXT,
  representant_nom TEXT,
  telephone TEXT,
  ville TEXT,
  adresse TEXT,
  observations TEXT,
  statut TEXT NOT NULL DEFAULT 'brouillon',
  date_commande DATE NOT NULL DEFAULT CURRENT_DATE,
  remise NUMERIC NOT NULL DEFAULT 0,
  nb_produits INTEGER NOT NULL DEFAULT 0,
  total_quantite INTEGER NOT NULL DEFAULT 0,
  total_ht_brut NUMERIC NOT NULL DEFAULT 0,
  total_remises_lignes NUMERIC NOT NULL DEFAULT 0,
  total_ht_net NUMERIC NOT NULL DEFAULT 0,
  remise_globale_pct NUMERIC NOT NULL DEFAULT 0,
  remise_globale_montant NUMERIC NOT NULL DEFAULT 0,
  taux_tva NUMERIC NOT NULL DEFAULT 0,
  montant_tva NUMERIC NOT NULL DEFAULT 0,
  montant_ttc NUMERIC NOT NULL DEFAULT 0,
  net_a_payer NUMERIC NOT NULL DEFAULT 0,
  montant_total NUMERIC NOT NULL DEFAULT 0,
  commercial_id UUID,
  commercial_nom TEXT,
  exercice_id UUID,
  depot_id UUID,
  notes TEXT,
  created_by UUID,
  created_by_nom TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.commandes TO authenticated;
GRANT ALL ON public.commandes TO service_role;
ALTER TABLE public.commandes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "commandes read auth" ON public.commandes FOR SELECT TO authenticated USING (true);
CREATE POLICY "commandes write auth" ON public.commandes FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE TRIGGER update_commandes_updated_at BEFORE UPDATE ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_commandes_client_id ON public.commandes(client_id);
CREATE INDEX idx_commandes_statut ON public.commandes(statut);
CREATE INDEX idx_commandes_date ON public.commandes(date_commande DESC);

-- Table commande_lignes
CREATE TABLE public.commande_lignes (
  ligne_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commande_id UUID NOT NULL REFERENCES public.commandes(commande_id) ON DELETE CASCADE,
  produit_id UUID,
  reference_produit TEXT,
  designation TEXT NOT NULL,
  quantite INTEGER NOT NULL DEFAULT 0,
  prix_unitaire NUMERIC NOT NULL DEFAULT 0,
  remise_pct NUMERIC NOT NULL DEFAULT 0,
  montant_remise NUMERIC NOT NULL DEFAULT 0,
  total_ligne NUMERIC NOT NULL DEFAULT 0,
  total_ht_ligne NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.commande_lignes TO authenticated;
GRANT ALL ON public.commande_lignes TO service_role;
ALTER TABLE public.commande_lignes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "commande_lignes read auth" ON public.commande_lignes FOR SELECT TO authenticated USING (true);
CREATE POLICY "commande_lignes write auth" ON public.commande_lignes FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE TRIGGER update_commande_lignes_updated_at BEFORE UPDATE ON public.commande_lignes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_cmd_lignes_commande ON public.commande_lignes(commande_id);
CREATE INDEX idx_cmd_lignes_produit ON public.commande_lignes(produit_id);
