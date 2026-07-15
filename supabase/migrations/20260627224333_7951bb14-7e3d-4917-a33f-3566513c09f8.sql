CREATE TABLE public.stock_mouvements (
  mouvement_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  produit_id uuid NOT NULL REFERENCES public.produits(produit_id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'entree',
  quantite integer NOT NULL DEFAULT 0,
  stock_resultant integer NOT NULL DEFAULT 0,
  motif text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.stock_mouvements TO authenticated;
GRANT ALL ON public.stock_mouvements TO service_role;

ALTER TABLE public.stock_mouvements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can view mouvements" ON public.stock_mouvements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Staff can insert mouvements" ON public.stock_mouvements FOR INSERT TO authenticated WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.apply_stock_mouvement()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_stock integer;
  new_stock integer;
BEGIN
  SELECT stock INTO current_stock FROM public.produits WHERE produit_id = NEW.produit_id FOR UPDATE;
  IF current_stock IS NULL THEN
    RAISE EXCEPTION 'Produit introuvable';
  END IF;

  IF NEW.type = 'entree' THEN
    new_stock := current_stock + NEW.quantite;
  ELSIF NEW.type = 'sortie' THEN
    new_stock := current_stock - NEW.quantite;
  ELSE
    new_stock := NEW.quantite;
  END IF;

  IF new_stock < 0 THEN
    new_stock := 0;
  END IF;

  UPDATE public.produits SET stock = new_stock, updated_at = now() WHERE produit_id = NEW.produit_id;
  NEW.stock_resultant := new_stock;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_apply_stock_mouvement
  BEFORE INSERT ON public.stock_mouvements
  FOR EACH ROW EXECUTE FUNCTION public.apply_stock_mouvement();