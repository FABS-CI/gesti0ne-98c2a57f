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
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.paiements TO authenticated;
GRANT ALL ON public.paiements TO service_role;

ALTER TABLE public.paiements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can view paiements" ON public.paiements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff can insert paiements" ON public.paiements FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update paiements" ON public.paiements FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Staff can delete paiements" ON public.paiements FOR DELETE TO authenticated USING (true);

CREATE TRIGGER update_paiements_updated_at BEFORE UPDATE ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();