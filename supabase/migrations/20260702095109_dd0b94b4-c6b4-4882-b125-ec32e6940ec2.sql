ALTER TABLE public.livsuivi_commandes
  ADD COLUMN IF NOT EXISTS bl_id uuid REFERENCES public.bons_livraison(bl_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS nb_cartons integer;