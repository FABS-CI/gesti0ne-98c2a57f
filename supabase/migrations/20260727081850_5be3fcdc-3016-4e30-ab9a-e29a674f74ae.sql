ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS route_restrictions text[] NOT NULL DEFAULT '{}';

UPDATE public.profiles
SET route_restrictions = ARRAY['/incidents', '/alertes-stock', '/transferts']
WHERE lower(email) = 'yakeben@editionsfabsci.com';