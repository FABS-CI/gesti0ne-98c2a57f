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
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.produits TO authenticated;
GRANT ALL ON public.produits TO service_role;

ALTER TABLE public.produits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can view produits" ON public.produits FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff can insert produits" ON public.produits FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update produits" ON public.produits FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Staff can delete produits" ON public.produits FOR DELETE TO authenticated USING (true);

CREATE TRIGGER update_produits_updated_at BEFORE UPDATE ON public.produits
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();