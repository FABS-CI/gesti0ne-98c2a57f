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

CREATE TRIGGER update_commandes_updated_at BEFORE UPDATE ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();