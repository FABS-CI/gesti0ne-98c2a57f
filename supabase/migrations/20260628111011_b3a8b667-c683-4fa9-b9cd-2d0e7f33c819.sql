ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS nif text,
  ADD COLUMN IF NOT EXISTS regime_fiscal text,
  ADD COLUMN IF NOT EXISTS contact_principal text,
  ADD COLUMN IF NOT EXISTS telephone2 text,
  ADD COLUMN IF NOT EXISTS quartier text,
  ADD COLUMN IF NOT EXISTS bp text,
  ADD COLUMN IF NOT EXISTS pays text DEFAULT 'Côte d''Ivoire',
  ADD COLUMN IF NOT EXISTS remise_habituelle numeric(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS mode_paiement text DEFAULT 'comptant',
  ADD COLUMN IF NOT EXISTS delai_paiement integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS categorie text,
  ADD COLUMN IF NOT EXISTS secteur_activite text,
  ADD COLUMN IF NOT EXISTS statut text DEFAULT 'actif',
  ADD COLUMN IF NOT EXISTS motif_blocage text;

CREATE INDEX IF NOT EXISTS idx_clients_nom ON public.clients(nom);
CREATE INDEX IF NOT EXISTS idx_clients_telephone ON public.clients(telephone);
CREATE INDEX IF NOT EXISTS idx_clients_statut ON public.clients(statut);
CREATE INDEX IF NOT EXISTS idx_clients_ville ON public.clients(ville);