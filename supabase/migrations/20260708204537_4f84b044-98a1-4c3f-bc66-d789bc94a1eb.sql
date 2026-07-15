
CREATE OR REPLACE FUNCTION public.sync_produit_stock_from_depots()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_pid uuid;
BEGIN
  v_pid := COALESCE(NEW.produit_id, OLD.produit_id);
  IF v_pid IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;

  UPDATE public.produits
     SET stock = COALESCE((
       SELECT sum(quantite)::int FROM public.stocks_depots WHERE produit_id = v_pid
     ), 0),
         updated_at = now()
   WHERE produit_id = v_pid;

  -- Si un changement de produit dans un UPDATE, resync l'ancien
  IF TG_OP = 'UPDATE' AND OLD.produit_id IS DISTINCT FROM NEW.produit_id AND OLD.produit_id IS NOT NULL THEN
    UPDATE public.produits
       SET stock = COALESCE((
         SELECT sum(quantite)::int FROM public.stocks_depots WHERE produit_id = OLD.produit_id
       ), 0),
           updated_at = now()
     WHERE produit_id = OLD.produit_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_produit_stock ON public.stocks_depots;
CREATE TRIGGER trg_sync_produit_stock
AFTER INSERT OR UPDATE OR DELETE ON public.stocks_depots
FOR EACH ROW EXECUTE FUNCTION public.sync_produit_stock_from_depots();
