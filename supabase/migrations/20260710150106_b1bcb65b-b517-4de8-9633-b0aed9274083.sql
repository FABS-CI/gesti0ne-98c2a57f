ALTER TABLE public.produits
  ADD COLUMN IF NOT EXISTS pin_order smallint
  GENERATED ALWAYS AS (CASE WHEN produit_id = 'f8572bf4-4da3-430f-874f-98972a1f9d17'::uuid THEN 0 ELSE 1 END) STORED;

CREATE INDEX IF NOT EXISTS produits_pin_order_idx ON public.produits(pin_order);