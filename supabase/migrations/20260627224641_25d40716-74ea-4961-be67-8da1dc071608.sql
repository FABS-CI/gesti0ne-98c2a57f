CREATE SEQUENCE IF NOT EXISTS public.transaction_ref_seq;

CREATE TABLE public.transactions (
  transaction_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference text NOT NULL UNIQUE DEFAULT ('TRX-' || lpad(nextval('public.transaction_ref_seq')::text, 5, '0')),
  type text NOT NULL CHECK (type IN ('recette', 'depense')),
  categorie text NOT NULL DEFAULT 'autre',
  libelle text NOT NULL,
  montant numeric NOT NULL DEFAULT 0,
  mode_paiement text NOT NULL DEFAULT 'especes',
  statut text NOT NULL DEFAULT 'valide' CHECK (statut IN ('valide', 'en_attente', 'annule')),
  date_transaction date NOT NULL DEFAULT CURRENT_DATE,
  commande_id uuid REFERENCES public.commandes(commande_id) ON DELETE SET NULL,
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