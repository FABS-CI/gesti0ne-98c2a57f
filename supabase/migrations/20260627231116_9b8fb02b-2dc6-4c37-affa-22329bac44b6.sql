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
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.factures TO authenticated;
GRANT ALL ON public.factures TO service_role;

ALTER TABLE public.factures ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can view factures" ON public.factures FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff can insert factures" ON public.factures FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Staff can update factures" ON public.factures FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Staff can delete factures" ON public.factures FOR DELETE TO authenticated USING (true);

CREATE TRIGGER update_factures_updated_at BEFORE UPDATE ON public.factures
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();