
-- Prévention des doublons clients (par nom normalisé)
-- N'affecte pas l'existant : bloque uniquement les nouveaux doublons
CREATE OR REPLACE FUNCTION public.prevent_client_duplicates()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_norm text;
  v_exists uuid;
BEGIN
  v_norm := LOWER(TRIM(NEW.nom));
  IF v_norm IS NULL OR v_norm = '' THEN RETURN NEW; END IF;
  IF NEW.actif IS NOT TRUE THEN RETURN NEW; END IF;

  SELECT client_id INTO v_exists
  FROM public.clients
  WHERE actif = true
    AND LOWER(TRIM(nom)) = v_norm
    AND client_id <> NEW.client_id
  LIMIT 1;

  IF v_exists IS NOT NULL THEN
    RAISE EXCEPTION 'Un client actif avec le nom "%" existe déjà (id=%). Merci d''utiliser le client existant ou de modifier le nom.', NEW.nom, v_exists
      USING ERRCODE = 'unique_violation';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.prevent_client_duplicates() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_prevent_client_duplicates ON public.clients;
CREATE TRIGGER trg_prevent_client_duplicates
  BEFORE INSERT OR UPDATE OF nom, actif ON public.clients
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_client_duplicates();

-- Index de recherche accélérée sur nom normalisé
CREATE INDEX IF NOT EXISTS idx_clients_nom_norm
  ON public.clients (LOWER(TRIM(nom))) WHERE actif = true;
