CREATE TABLE public.proforma_lignes (
  ligne_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  proforma_id uuid NOT NULL REFERENCES public.proformas(proforma_id) ON DELETE CASCADE,
  produit_id uuid,
  designation text NOT NULL,
  quantite integer NOT NULL DEFAULT 1,
  prix_unitaire numeric NOT NULL DEFAULT 0,
  total_ligne numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.proforma_lignes TO authenticated;
GRANT ALL ON public.proforma_lignes TO service_role;

ALTER TABLE public.proforma_lignes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff peut voir les lignes de proforma" ON public.proforma_lignes FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff peut creer les lignes de proforma" ON public.proforma_lignes FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff peut modifier les lignes de proforma" ON public.proforma_lignes FOR UPDATE TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff peut supprimer les lignes de proforma" ON public.proforma_lignes FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

CREATE INDEX idx_proforma_lignes_proforma_id ON public.proforma_lignes(proforma_id);