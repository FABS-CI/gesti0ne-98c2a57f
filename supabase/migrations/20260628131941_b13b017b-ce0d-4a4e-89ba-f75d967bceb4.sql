ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS statut text NOT NULL DEFAULT 'valide',
  ADD COLUMN IF NOT EXISTS commande_id uuid REFERENCES public.commandes(commande_id) ON DELETE SET NULL;