
CREATE OR REPLACE FUNCTION public.generate_client_reference()
RETURNS text
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  ref text;
  i int;
  exists_count int;
BEGIN
  LOOP
    ref := '';
    FOR i IN 1..5 LOOP
      ref := ref || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    END LOOP;
    SELECT count(*) INTO exists_count FROM public.clients WHERE reference = ref;
    EXIT WHEN exists_count = 0;
  END LOOP;
  RETURN ref;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_client_reference()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.reference IS NULL OR btrim(NEW.reference) = '' THEN
    NEW.reference := public.generate_client_reference();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_client_reference ON public.clients;
CREATE TRIGGER trg_set_client_reference
BEFORE INSERT ON public.clients
FOR EACH ROW EXECUTE FUNCTION public.set_client_reference();

-- Backfill existing empty references
UPDATE public.clients
SET reference = public.generate_client_reference()
WHERE reference IS NULL OR btrim(reference) = '';
