
-- Empêche toute modification directe de produits.stock depuis l'application.
-- Autorise : SECURITY DEFINER (current_user = postgres) et service_role.
CREATE OR REPLACE FUNCTION public.guard_produits_stock_readonly()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.stock IS DISTINCT FROM OLD.stock
     AND current_user IN ('authenticated', 'anon') THEN
    RAISE EXCEPTION 'Modification directe du stock interdite. Utiliser un mouvement de stock (réception, vente, ajustement, inventaire, transfert…).'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_produits_stock_readonly ON public.produits;
CREATE TRIGGER trg_produits_stock_readonly
  BEFORE UPDATE OF stock ON public.produits
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_produits_stock_readonly();

-- Idem pour stocks_depots.quantite
CREATE OR REPLACE FUNCTION public.guard_stocks_depots_readonly()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.quantite IS DISTINCT FROM OLD.quantite
     AND current_user IN ('authenticated', 'anon') THEN
    RAISE EXCEPTION 'Modification directe de la quantité en dépôt interdite. Utiliser un mouvement de stock.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stocks_depots_readonly ON public.stocks_depots;
CREATE TRIGGER trg_stocks_depots_readonly
  BEFORE UPDATE OF quantite ON public.stocks_depots
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_stocks_depots_readonly();
