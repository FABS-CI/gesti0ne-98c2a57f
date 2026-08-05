-- Étape 9 — Workflows d'approbation (Renforcement RBAC v3)
-- Intégration des inventaires et ajustements de stock dans le moteur d'approbation central.

CREATE OR REPLACE FUNCTION public.inventaire_demander_validation(_inventaire_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_inv record;
  v_appr_id uuid;
  v_user_nom text := public._current_user_display_name();
BEGIN
  SELECT * INTO v_inv FROM public.inventaires WHERE inventaire_id = _inventaire_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Inventaire introuvable'; END IF;
  
  IF v_inv.statut <> 'en_cours' THEN
    RAISE EXCEPTION 'L''inventaire doit être en cours pour demander une validation';
  END IF;

  INSERT INTO public.workflow_approvals (
    workflow_code, module, entity_type, entity_id, reference,
    statut, demandeur_id, demandeur_nom, niveau_urgence, metadata
  ) VALUES (
    'inventaire_validation', 'inventaires', 'inventaire', _inventaire_id, v_inv.reference,
    'en_attente', auth.uid(), v_user_nom, 'normal',
    jsonb_build_object('objet', 'Validation de l''inventaire ' || v_inv.reference)
  ) RETURNING id INTO v_appr_id;

  UPDATE public.inventaires SET statut = 'attente_validation' WHERE inventaire_id = _inventaire_id;
  
  RETURN v_appr_id;
END; $$;

-- Mise à jour de ajuster_stock_depot pour exiger une approbation si non admin
CREATE OR REPLACE FUNCTION public.ajuster_stock_depot_v3(
  _produit_id uuid, _depot_id uuid, _nouvelle_quantite numeric, _motif text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_ancienne numeric;
  v_delta numeric;
  v_ref text;
  v_user_nom text := public._current_user_display_name();
BEGIN
  IF NOT public.rbac3_can('stocks.modifier') THEN
    RAISE EXCEPTION 'Permission refusée : stocks.modifier' USING ERRCODE = '42501';
  END IF;

  -- Si l'utilisateur n'a pas la permission de valider auto, on crée une demande d'ajustement
  -- (Optionnel : ici on applique direct si admin, sinon on pourrait forcer un workflow)
  -- Pour l'instant, on applique la règle de périmètre (Step 8)
  
  IF NOT public.rbac3_can('super_admin') THEN
    -- Vérifier si l'utilisateur a accès à ce dépôt
    IF NOT EXISTS (SELECT 1 FROM public.user_depots WHERE user_id = auth.uid() AND depot_id = _depot_id) THEN
      RAISE EXCEPTION 'Accès refusé à ce dépôt' USING ERRCODE = '42501';
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

-- Suppression des anciennes versions si nécessaire
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
