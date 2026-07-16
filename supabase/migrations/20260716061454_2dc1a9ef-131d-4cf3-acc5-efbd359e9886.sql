
-- 1. Table stocks_depots
CREATE TABLE IF NOT EXISTS public.stocks_depots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  produit_id uuid NOT NULL REFERENCES public.produits(produit_id) ON DELETE CASCADE,
  depot_id uuid NOT NULL REFERENCES public.depots(depot_id) ON DELETE CASCADE,
  quantite numeric NOT NULL DEFAULT 0,
  seuil_alerte numeric NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (produit_id, depot_id)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.stocks_depots TO authenticated;
GRANT ALL ON public.stocks_depots TO service_role;

ALTER TABLE public.stocks_depots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_read_stocks_depots" ON public.stocks_depots
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_write_stocks_depots" ON public.stocks_depots
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_stocks_depots_produit ON public.stocks_depots(produit_id);
CREATE INDEX IF NOT EXISTS idx_stocks_depots_depot ON public.stocks_depots(depot_id);

CREATE TRIGGER update_stocks_depots_updated_at
  BEFORE UPDATE ON public.stocks_depots
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 2. Colonnes manquantes transferts
ALTER TABLE public.transferts
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS transporteur text,
  ADD COLUMN IF NOT EXISTS date_creation timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS date_expedition timestamptz,
  ADD COLUMN IF NOT EXISTS date_reception timestamptz,
  ADD COLUMN IF NOT EXISTS created_by uuid;

ALTER TABLE public.transferts ALTER COLUMN statut SET DEFAULT 'brouillon';

-- 3. Colonnes manquantes transfert_lignes
ALTER TABLE public.transfert_lignes
  ADD COLUMN IF NOT EXISTS quantite_recue numeric NOT NULL DEFAULT 0;

-- 4. RPCs
CREATE OR REPLACE FUNCTION public.definir_depot_principal(_depot_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.depots SET is_principal = false WHERE is_principal = true;
  UPDATE public.depots SET is_principal = true, actif = true WHERE depot_id = _depot_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.ajuster_stock_depot(
  _produit_id uuid,
  _depot_id uuid,
  _nouvelle_quantite numeric,
  _motif text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ancienne numeric;
  v_delta numeric;
BEGIN
  SELECT quantite INTO v_ancienne
  FROM public.stocks_depots
  WHERE produit_id = _produit_id AND depot_id = _depot_id;

  IF v_ancienne IS NULL THEN
    INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
    VALUES (_produit_id, _depot_id, _nouvelle_quantite);
    v_ancienne := 0;
  ELSE
    UPDATE public.stocks_depots
    SET quantite = _nouvelle_quantite, updated_at = now()
    WHERE produit_id = _produit_id AND depot_id = _depot_id;
  END IF;

  v_delta := _nouvelle_quantite - v_ancienne;

  INSERT INTO public.stock_mouvements(
    produit_id, depot_id, type, quantite,
    quantite_entree, quantite_sortie, stock_resultant,
    motif, origine, user_id
  )
  VALUES (
    _produit_id, _depot_id, 'ajustement', v_delta,
    GREATEST(v_delta, 0), GREATEST(-v_delta, 0), _nouvelle_quantite,
    _motif, 'ajustement', auth.uid()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.executer_transfert(_transfert_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_source uuid;
  v_dest uuid;
  v_statut text;
  r record;
  v_stock numeric;
BEGIN
  SELECT depot_source_id, depot_destination_id, statut
    INTO v_source, v_dest, v_statut
  FROM public.transferts WHERE transfert_id = _transfert_id;

  IF v_source IS NULL THEN RAISE EXCEPTION 'Transfert introuvable'; END IF;
  IF v_statut <> 'brouillon' THEN RAISE EXCEPTION 'Statut invalide : %', v_statut; END IF;

  FOR r IN
    SELECT produit_id, quantite FROM public.transfert_lignes WHERE transfert_id = _transfert_id
  LOOP
    SELECT COALESCE(quantite, 0) INTO v_stock
    FROM public.stocks_depots
    WHERE produit_id = r.produit_id AND depot_id = v_source;

    IF COALESCE(v_stock, 0) < r.quantite THEN
      RAISE EXCEPTION 'Stock insuffisant pour produit %', r.produit_id;
    END IF;

    UPDATE public.stocks_depots
    SET quantite = quantite - r.quantite, updated_at = now()
    WHERE produit_id = r.produit_id AND depot_id = v_source;

    INSERT INTO public.stock_mouvements(produit_id, depot_id, type, quantite,
      quantite_entree, quantite_sortie, stock_resultant,
      origine, document_id, user_id)
    SELECT r.produit_id, v_source, 'sortie', r.quantite,
      0, r.quantite, quantite,
      'transfert_sortant', _transfert_id, auth.uid()
    FROM public.stocks_depots
    WHERE produit_id = r.produit_id AND depot_id = v_source;
  END LOOP;

  UPDATE public.transferts
  SET statut = 'expedie', date_expedition = now()
  WHERE transfert_id = _transfert_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.receptionner_transfert(_transfert_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dest uuid;
  v_statut text;
  r record;
BEGIN
  SELECT depot_destination_id, statut INTO v_dest, v_statut
  FROM public.transferts WHERE transfert_id = _transfert_id;

  IF v_dest IS NULL THEN RAISE EXCEPTION 'Transfert introuvable'; END IF;
  IF v_statut <> 'expedie' THEN RAISE EXCEPTION 'Statut invalide : %', v_statut; END IF;

  FOR r IN
    SELECT produit_id, quantite FROM public.transfert_lignes WHERE transfert_id = _transfert_id
  LOOP
    INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
    VALUES (r.produit_id, v_dest, r.quantite)
    ON CONFLICT (produit_id, depot_id) DO UPDATE
      SET quantite = public.stocks_depots.quantite + EXCLUDED.quantite,
          updated_at = now();

    UPDATE public.transfert_lignes
    SET quantite_recue = r.quantite
    WHERE transfert_id = _transfert_id AND produit_id = r.produit_id;

    INSERT INTO public.stock_mouvements(produit_id, depot_id, type, quantite,
      quantite_entree, quantite_sortie, stock_resultant,
      origine, document_id, user_id)
    SELECT r.produit_id, v_dest, 'entree', r.quantite,
      r.quantite, 0, quantite,
      'transfert_entrant', _transfert_id, auth.uid()
    FROM public.stocks_depots
    WHERE produit_id = r.produit_id AND depot_id = v_dest;
  END LOOP;

  UPDATE public.transferts
  SET statut = 'recu', date_reception = now()
  WHERE transfert_id = _transfert_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.annuler_transfert(_transfert_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.transferts SET statut = 'annule'
  WHERE transfert_id = _transfert_id AND statut IN ('brouillon', 'expedie');
END;
$$;

GRANT EXECUTE ON FUNCTION public.definir_depot_principal(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ajuster_stock_depot(uuid, uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.executer_transfert(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.receptionner_transfert(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.annuler_transfert(uuid) TO authenticated;
