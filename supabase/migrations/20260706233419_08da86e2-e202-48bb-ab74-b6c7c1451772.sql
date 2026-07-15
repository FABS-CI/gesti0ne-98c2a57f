
-- 1) Base36 padded helper
CREATE OR REPLACE FUNCTION public.to_base36(n bigint, width int DEFAULT 5)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  digits text := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  result text := '';
  q bigint := n;
BEGIN
  IF n < 0 THEN RAISE EXCEPTION 'to_base36 requires n >= 0'; END IF;
  IF n = 0 THEN result := '0';
  ELSE
    WHILE q > 0 LOOP
      result := substr(digits, (q % 36)::int + 1, 1) || result;
      q := q / 36;
    END LOOP;
  END IF;
  RETURN lpad(result, width, '0');
END;
$$;

-- 2) Clients sequence + renumbering
CREATE SEQUENCE IF NOT EXISTS public.clients_ref_seq START 1;

WITH ordered AS (
  SELECT client_id, row_number() OVER (ORDER BY created_at, client_id) AS rn
  FROM public.clients
)
UPDATE public.clients c
SET reference = public.to_base36(o.rn, 5)
FROM ordered o
WHERE c.client_id = o.client_id;

SELECT setval('public.clients_ref_seq', GREATEST((SELECT count(*) FROM public.clients), 1));

ALTER TABLE public.clients
  ALTER COLUMN reference SET DEFAULT public.to_base36(nextval('public.clients_ref_seq'), 5);

-- Unique reference to prevent collisions
CREATE UNIQUE INDEX IF NOT EXISTS clients_reference_key ON public.clients(reference);

-- 3) Sales documents: switch defaults to base36 5-char (tables are empty)
ALTER SEQUENCE public.proformas_ref_seq RESTART WITH 1;
ALTER SEQUENCE public.commande_ref_seq RESTART WITH 1;
ALTER SEQUENCE public.factures_ref_seq RESTART WITH 1;
ALTER SEQUENCE public.paiements_ref_seq RESTART WITH 1;
ALTER SEQUENCE public.livraisons_ref_seq RESTART WITH 1;

ALTER TABLE public.proformas
  ALTER COLUMN reference SET DEFAULT public.to_base36(nextval('public.proformas_ref_seq'), 5);
ALTER TABLE public.commandes
  ALTER COLUMN reference SET DEFAULT public.to_base36(nextval('public.commande_ref_seq'), 5);
ALTER TABLE public.factures
  ALTER COLUMN reference SET DEFAULT public.to_base36(nextval('public.factures_ref_seq'), 5);
ALTER TABLE public.paiements
  ALTER COLUMN reference SET DEFAULT public.to_base36(nextval('public.paiements_ref_seq'), 5);
ALTER TABLE public.livraisons
  ALTER COLUMN reference SET DEFAULT public.to_base36(nextval('public.livraisons_ref_seq'), 5);

-- BL / BR: no existing sequence, create one and use it
CREATE SEQUENCE IF NOT EXISTS public.bons_livraison_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.bons_retour_ref_seq START 1;

ALTER TABLE public.bons_livraison
  ALTER COLUMN reference SET DEFAULT public.to_base36(nextval('public.bons_livraison_ref_seq'), 5);
ALTER TABLE public.bons_retour
  ALTER COLUMN reference SET DEFAULT public.to_base36(nextval('public.bons_retour_ref_seq'), 5);
