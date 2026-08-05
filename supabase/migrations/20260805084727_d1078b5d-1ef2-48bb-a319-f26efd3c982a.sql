-- Remplacement de la fonction ajuster_stock_depot par la version sécurisée V3
CREATE OR REPLACE FUNCTION public.ajuster_stock_depot(
  _produit_id uuid, _depot_id uuid, _nouvelle_quantite numeric, _motif text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_ancienne numeric;
  v_delta numeric;
  v_user_nom text := public._current_user_display_name();
BEGIN
  -- 1) Vérification des permissions RBAC v3
  IF NOT public.rbac3_can('stocks.modifier') THEN
    RAISE EXCEPTION 'Permission refusée : stocks.modifier' USING ERRCODE = '42501';
  END IF;

  -- 2) Vérification de la portée (Scope Step 8)
  -- Seul super_admin a une portée globale. Les autres sont limités à leurs dépôts.
  IF NOT public.rbac3_can('super_admin') THEN
    IF NOT EXISTS (SELECT 1 FROM public.user_depots WHERE user_id = auth.uid() AND depot_id = _depot_id) THEN
      RAISE EXCEPTION 'Accès refusé : vous n''avez pas accès à ce dépôt' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT quantite INTO v_ancienne FROM public.stocks_depots WHERE produit_id = _produit_id AND depot_id = _depot_id;
  v_delta := _nouvelle_quantite - COALESCE(v_ancienne, 0);

  IF v_ancienne IS NULL THEN
    INSERT INTO public.stocks_depots(produit_id, depot_id, quantite) VALUES (_produit_id, _depot_id, _nouvelle_quantite);
  ELSE
    UPDATE public.stocks_depots SET quantite = _nouvelle_quantite, updated_at = now() WHERE produit_id = _produit_id AND depot_id = _depot_id;
  END IF;

  INSERT INTO public.stock_mouvements(
    produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie, stock_resultant,
    motif, origine, user_id, user_nom
  ) VALUES (
    _produit_id, _depot_id, 'ajustement', v_delta, GREATEST(v_delta, 0), GREATEST(-v_delta, 0), _nouvelle_quantite,
    _motif, 'ajustement', auth.uid(), v_user_nom
  );
END; $$;
