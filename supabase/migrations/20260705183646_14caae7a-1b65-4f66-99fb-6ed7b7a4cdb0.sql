
-- (Re)crée le trigger de synchronisation colis → tournées.
-- La fonction recalc_tournee_from_colis existe déjà (SECURITY DEFINER) et ne
-- met à jour que les tournées du même jour en statut 'preparee' ou 'en_cours'.

CREATE OR REPLACE FUNCTION public.trg_colis_sync_tournee_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recalc_tournee_from_colis(OLD.date_colisage);
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM public.recalc_tournee_from_colis(OLD.date_colisage);
    IF NEW.date_colisage IS DISTINCT FROM OLD.date_colisage THEN
      PERFORM public.recalc_tournee_from_colis(NEW.date_colisage);
    END IF;
    RETURN NEW;
  ELSE
    PERFORM public.recalc_tournee_from_colis(NEW.date_colisage);
    RETURN NEW;
  END IF;
END $$;

DROP TRIGGER IF EXISTS trg_colis_sync_tournee ON public.colis;
CREATE TRIGGER trg_colis_sync_tournee
AFTER INSERT OR UPDATE OR DELETE ON public.colis
FOR EACH ROW EXECUTE FUNCTION public.trg_colis_sync_tournee_fn();

-- REPLICA IDENTITY FULL pour que Realtime diffuse les anciennes valeurs
ALTER TABLE public.tournees REPLICA IDENTITY FULL;
