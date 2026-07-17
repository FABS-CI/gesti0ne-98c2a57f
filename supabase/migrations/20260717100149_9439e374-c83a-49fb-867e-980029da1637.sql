-- =====================================================================
-- Lot 2 : Durcissement RBAC — Stock / Inventaires / Transferts / Dépôts
-- Ajoute un contrôle has_permission() au démarrage de chaque RPC sensible.
-- =====================================================================

-- 1) STOCK ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ajuster_stock_depot(
  _produit_id uuid, _depot_id uuid, _nouvelle_quantite numeric, _motif text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_ancienne numeric;
  v_delta numeric;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'stock.creer_mouvement') THEN
    RAISE EXCEPTION 'Permission refusée : stock.creer_mouvement' USING ERRCODE = '42501';
  END IF;

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
$function$;

-- 2) INVENTAIRES ------------------------------------------------------
CREATE OR REPLACE FUNCTION public.annuler_inventaire(_inventaire_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_statut text;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'inventaires.annuler') THEN
    RAISE EXCEPTION 'Permission refusée : inventaires.annuler' USING ERRCODE = '42501';
  END IF;

  SELECT statut INTO v_statut FROM public.inventaires WHERE inventaire_id = _inventaire_id;
  IF v_statut IS NULL THEN
    RAISE EXCEPTION 'Inventaire introuvable';
  END IF;
  IF v_statut IN ('valide','regularise','annule') THEN
    RAISE EXCEPTION 'Inventaire non annulable (statut: %)', v_statut;
  END IF;
  UPDATE public.inventaires
     SET statut = 'annule', updated_at = now()
   WHERE inventaire_id = _inventaire_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.creer_inventaire_physique(_payload jsonb)
RETURNS SETOF inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_id uuid; v_ref text;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'inventaires.creer') THEN
    RAISE EXCEPTION 'Permission refusée : inventaires.creer' USING ERRCODE = '42501';
  END IF;

  v_ref := public._next_ref('INV', 'public.inventaires', 'reference');

  INSERT INTO public.inventaires(reference, depot_id, date_inventaire, statut, notes)
  VALUES (v_ref,
    NULLIF(_payload->>'depot_id','')::uuid,
    COALESCE((_payload->>'date_inventaire')::date, current_date),
    'en_cours',
    _payload->>'observations')
  RETURNING inventaire_id INTO v_id;

  INSERT INTO public.inventaire_lignes(inventaire_id, produit_id, designation, quantite_theorique, quantite_physique)
  SELECT v_id, p.produit_id, p.titre, COALESCE(sd.quantite, 0), 0
  FROM public.produits p
  LEFT JOIN public.stocks_depots sd
    ON sd.produit_id = p.produit_id AND sd.depot_id = NULLIF(_payload->>'depot_id','')::uuid
  WHERE p.actif IS NOT FALSE;

  RETURN QUERY SELECT * FROM public.inventaires WHERE inventaire_id = v_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.creer_inventaire_theorique(_payload jsonb)
RETURNS SETOF inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'inventaires.creer') THEN
    RAISE EXCEPTION 'Permission refusée : inventaires.creer' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY SELECT * FROM public.creer_inventaire_physique(_payload);
END; $function$;

CREATE OR REPLACE FUNCTION public.creer_inventaire_global(_payload jsonb)
RETURNS SETOF inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_id uuid; v_ref text;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'inventaires.creer') THEN
    RAISE EXCEPTION 'Permission refusée : inventaires.creer' USING ERRCODE = '42501';
  END IF;

  v_ref := public._next_ref('INV', 'public.inventaires', 'reference');

  INSERT INTO public.inventaires(reference, date_inventaire, statut, notes)
  VALUES (v_ref, COALESCE((_payload->>'date_inventaire')::date, current_date),
          'en_cours', _payload->>'observations')
  RETURNING inventaire_id INTO v_id;

  INSERT INTO public.inventaire_lignes(inventaire_id, produit_id, designation, quantite_theorique, quantite_physique)
  SELECT v_id, p.produit_id, p.titre,
         COALESCE((SELECT sum(quantite) FROM public.stocks_depots sd WHERE sd.produit_id = p.produit_id), 0), 0
  FROM public.produits p WHERE p.actif IS NOT FALSE;

  RETURN QUERY SELECT * FROM public.inventaires WHERE inventaire_id = v_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.valider_inventaire_physique(_inventaire_id uuid, _lignes jsonb)
RETURNS SETOF inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_ligne jsonb; v_ecart_total numeric := 0; v_ecart numeric;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'inventaires.valider') THEN
    RAISE EXCEPTION 'Permission refusée : inventaires.valider' USING ERRCODE = '42501';
  END IF;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(COALESCE(_lignes,'[]'::jsonb)) LOOP
    v_ecart := COALESCE((v_ligne->>'quantite_physique')::numeric,0) - COALESCE((v_ligne->>'quantite_theorique')::numeric,0);
    UPDATE public.inventaire_lignes SET
      quantite_physique = COALESCE((v_ligne->>'quantite_physique')::numeric,0),
      quantite_theorique = COALESCE((v_ligne->>'quantite_theorique')::numeric, quantite_theorique),
      ecart = v_ecart,
      observation = COALESCE(v_ligne->>'observation', observation)
    WHERE ligne_id = NULLIF(v_ligne->>'ligne_id','')::uuid
       OR (inventaire_id = _inventaire_id AND produit_id = NULLIF(v_ligne->>'produit_id','')::uuid);
    v_ecart_total := v_ecart_total + abs(v_ecart);
  END LOOP;

  UPDATE public.inventaires SET statut = 'valide', ecart_total = v_ecart_total
   WHERE inventaire_id = _inventaire_id;

  RETURN QUERY SELECT * FROM public.inventaires WHERE inventaire_id = _inventaire_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.regulariser_inventaire(_inventaire_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_depot uuid; r record;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'inventaires.regulariser') THEN
    RAISE EXCEPTION 'Permission refusée : inventaires.regulariser' USING ERRCODE = '42501';
  END IF;

  SELECT depot_id INTO v_depot FROM public.inventaires WHERE inventaire_id = _inventaire_id;

  FOR r IN SELECT produit_id, quantite_physique, ecart FROM public.inventaire_lignes
           WHERE inventaire_id = _inventaire_id AND produit_id IS NOT NULL LOOP
    IF v_depot IS NOT NULL THEN
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES (r.produit_id, v_depot, r.quantite_physique)
      ON CONFLICT (produit_id, depot_id) DO UPDATE
        SET quantite = EXCLUDED.quantite, updated_at = now();

      INSERT INTO public.stock_mouvements(produit_id, depot_id, type, quantite,
        quantite_entree, quantite_sortie, stock_resultant, origine, document_id, user_id, motif)
      VALUES (r.produit_id, v_depot, 'ajustement', r.ecart,
        GREATEST(r.ecart,0), GREATEST(-r.ecart,0), r.quantite_physique,
        'inventaire', _inventaire_id, auth.uid(), 'Régularisation inventaire');
    END IF;
  END LOOP;

  UPDATE public.inventaires SET statut = 'regularise' WHERE inventaire_id = _inventaire_id;
END; $function$;

-- 3) TRANSFERTS -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.executer_transfert(_transfert_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_source uuid;
  v_dest uuid;
  v_statut text;
  r record;
  v_stock numeric;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'transferts.executer') THEN
    RAISE EXCEPTION 'Permission refusée : transferts.executer' USING ERRCODE = '42501';
  END IF;

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
$function$;

CREATE OR REPLACE FUNCTION public.receptionner_transfert(_transfert_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_dest uuid;
  v_statut text;
  r record;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'transferts.receptionner') THEN
    RAISE EXCEPTION 'Permission refusée : transferts.receptionner' USING ERRCODE = '42501';
  END IF;

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
$function$;

CREATE OR REPLACE FUNCTION public.annuler_transfert(_transfert_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'transferts.annuler') THEN
    RAISE EXCEPTION 'Permission refusée : transferts.annuler' USING ERRCODE = '42501';
  END IF;

  UPDATE public.transferts SET statut = 'annule'
  WHERE transfert_id = _transfert_id AND statut IN ('brouillon', 'expedie');
END;
$function$;

-- 4) DÉPÔTS -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.definir_depot_principal(_depot_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'depots.definir_principal') THEN
    RAISE EXCEPTION 'Permission refusée : depots.definir_principal' USING ERRCODE = '42501';
  END IF;

  UPDATE public.depots SET is_principal = false WHERE is_principal = true;
  UPDATE public.depots SET is_principal = true, actif = true WHERE depot_id = _depot_id;
END;
$function$;
