CREATE SEQUENCE IF NOT EXISTS public.transaction_ref_seq START 1;

CREATE TABLE IF NOT EXISTS public.transactions (
  transaction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text NOT NULL UNIQUE DEFAULT ('TRX-' || lpad(nextval('public.transaction_ref_seq')::text, 5, '0')),
  type text NOT NULL DEFAULT 'recette' CHECK (type IN ('recette', 'depense')),
  categorie text NOT NULL DEFAULT 'autre',
  libelle text NOT NULL,
  montant numeric NOT NULL DEFAULT 0,
  date_transaction date NOT NULL DEFAULT current_date,
  mode_paiement text NOT NULL DEFAULT 'especes',
  statut text NOT NULL DEFAULT 'valide' CHECK (statut IN ('valide', 'en_attente', 'annule')),
  notes text,
  commande_id uuid REFERENCES public.commandes(commande_id) ON DELETE SET NULL,
  exercice_id uuid,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT USAGE, SELECT ON SEQUENCE public.transaction_ref_seq TO authenticated;
GRANT ALL ON SEQUENCE public.transaction_ref_seq TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transactions TO authenticated;
GRANT ALL ON public.transactions TO service_role;

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "transactions read auth" ON public.transactions;
DROP POLICY IF EXISTS "transactions write auth" ON public.transactions;

CREATE POLICY "transactions read auth"
ON public.transactions
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "transactions write auth"
ON public.transactions
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_transactions_date ON public.transactions(date_transaction DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_statut ON public.transactions(statut);
CREATE INDEX IF NOT EXISTS idx_transactions_commande ON public.transactions(commande_id);
CREATE INDEX IF NOT EXISTS idx_transactions_exercice_type ON public.transactions(exercice_id, type);

DROP TRIGGER IF EXISTS update_transactions_updated_at ON public.transactions;
CREATE TRIGGER update_transactions_updated_at
BEFORE UPDATE ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

NOTIFY pgrst, 'reload schema';