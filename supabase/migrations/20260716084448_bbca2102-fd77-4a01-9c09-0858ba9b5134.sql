
-- =====================================================================
-- MODULE STOCK + ACHATS : reconstruction best-effort des RPC manquantes
-- =====================================================================

-- ---------- Produits ------------------------------------------------
CREATE OR REPLACE FUNCTION public.supprimer_produit(_produit_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ref text; v_used int;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT reference INTO v_ref FROM public.produits WHERE produit_id = _produit_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'Produit introuvable'; END IF;

  SELECT count(*) INTO v_used FROM public.commande_lignes WHERE produit_id = _produit_id;
  IF v_used > 0 THEN
    RAISE EXCEPTION 'Produit utilisé dans % commande(s) — désactivez-le au lieu de le supprimer', v_used;
  END IF;

  DELETE FROM public.stocks_depots WHERE produit_id = _produit_id;
  DELETE FROM public.produits WHERE produit_id = _produit_id;
  RETURN jsonb_build_object('produit_id', _produit_id, 'reference', v_ref, 'motif', _motif);
END; $$;

-- ---------- Fournisseurs --------------------------------------------
CREATE OR REPLACE FUNCTION public.supprimer_fournisseur(_fournisseur_id uuid, _motif text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_used int;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT count(*) INTO v_used FROM public.achats WHERE fournisseur_id = _fournisseur_id;
  IF v_used > 0 THEN
    RAISE EXCEPTION 'Fournisseur utilisé dans % achat(s)', v_used;
  END IF;
  DELETE FROM public.fournisseurs WHERE fournisseur_id = _fournisseur_id;
END; $$;

-- ---------- Achats --------------------------------------------------
CREATE OR REPLACE FUNCTION public.supprimer_achat(_achat_id uuid, _motif text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  DELETE FROM public.achats WHERE achat_id = _achat_id;
END; $$;

CREATE OR REPLACE FUNCTION public.receptionner_achat(_achat_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_statut text; v_depot uuid; r record;
BEGIN
  SELECT statut, depot_id INTO v_statut, v_depot FROM public.achats WHERE achat_id = _achat_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Achat introuvable'; END IF;
  IF v_statut = 'receptionne' THEN RAISE EXCEPTION 'Achat déjà réceptionné'; END IF;

  IF v_depot IS NOT NULL THEN
    FOR r IN SELECT produit_id, quantite FROM public.achat_lignes
             WHERE achat_id = _achat_id AND produit_id IS NOT NULL LOOP
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES (r.produit_id, v_depot, r.quantite)
      ON CONFLICT (produit_id, depot_id) DO UPDATE
        SET quantite = public.stocks_depots.quantite + EXCLUDED.quantite,
            updated_at = now();
      INSERT INTO public.stock_mouvements(produit_id, depot_id, type, quantite,
        quantite_entree, quantite_sortie, stock_resultant, origine, document_id, user_id)
      SELECT r.produit_id, v_depot, 'entree', r.quantite, r.quantite, 0, quantite,
             'achat', _achat_id, auth.uid()
      FROM public.stocks_depots WHERE produit_id = r.produit_id AND depot_id = v_depot;
    END LOOP;
  END IF;

  UPDATE public.achats SET statut = 'receptionne' WHERE achat_id = _achat_id;
END; $$;

CREATE OR REPLACE FUNCTION public.payer_achat(_achat_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.achats SET statut = 'paye' WHERE achat_id = _achat_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Achat introuvable'; END IF;
END; $$;

-- ---------- Approvisionnements --------------------------------------
CREATE OR REPLACE FUNCTION public.modifier_approvisionnement(_achat_id uuid, _payload jsonb)
RETURNS SETOF public.achats LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ligne jsonb; v_total numeric := 0;
BEGIN
  UPDATE public.achats SET
    fournisseur_id = COALESCE(NULLIF(_payload->>'fournisseur_id','')::uuid, fournisseur_id),
    depot_id = COALESCE(NULLIF(_payload->>'depot_id','')::uuid, depot_id),
    libelle = COALESCE(_payload->>'libelle', libelle),
    date_achat = COALESCE((_payload->>'date_achat')::date, date_achat),
    notes = COALESCE(_payload->>'notes', notes)
  WHERE achat_id = _achat_id;

  IF _payload ? 'lignes' THEN
    DELETE FROM public.achat_lignes WHERE achat_id = _achat_id;
    FOR v_ligne IN SELECT * FROM jsonb_array_elements(_payload->'lignes') LOOP
      INSERT INTO public.achat_lignes(achat_id, produit_id, reference_produit, designation,
        quantite, prix_unitaire, total_ligne)
      VALUES (_achat_id,
        NULLIF(v_ligne->>'produit_id','')::uuid,
        v_ligne->>'reference_produit',
        COALESCE(v_ligne->>'designation',''),
        COALESCE((v_ligne->>'quantite')::numeric, 0),
        COALESCE((v_ligne->>'prix_unitaire')::numeric, 0),
        COALESCE((v_ligne->>'quantite')::numeric,0) * COALESCE((v_ligne->>'prix_unitaire')::numeric,0));
      v_total := v_total + COALESCE((v_ligne->>'quantite')::numeric,0) * COALESCE((v_ligne->>'prix_unitaire')::numeric,0);
    END LOOP;
    UPDATE public.achats SET montant = v_total WHERE achat_id = _achat_id;
  END IF;

  RETURN QUERY SELECT * FROM public.achats WHERE achat_id = _achat_id;
END; $$;

-- ---------- Inventaires ---------------------------------------------
CREATE OR REPLACE FUNCTION public.creer_inventaire_physique(_payload jsonb)
RETURNS SETOF public.inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_ref text := public._next_ref('INV', 'public.inventaires', 'reference');
BEGIN
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
END; $$;

CREATE OR REPLACE FUNCTION public.creer_inventaire_theorique(_payload jsonb)
RETURNS SETOF public.inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY SELECT * FROM public.creer_inventaire_physique(_payload);
END; $$;

CREATE OR REPLACE FUNCTION public.creer_inventaire_global(_payload jsonb)
RETURNS SETOF public.inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_ref text := public._next_ref('INV', 'public.inventaires', 'reference');
BEGIN
  INSERT INTO public.inventaires(reference, date_inventaire, statut, notes)
  VALUES (v_ref, COALESCE((_payload->>'date_inventaire')::date, current_date),
          'en_cours', _payload->>'observations')
  RETURNING inventaire_id INTO v_id;

  INSERT INTO public.inventaire_lignes(inventaire_id, produit_id, designation, quantite_theorique, quantite_physique)
  SELECT v_id, p.produit_id, p.titre,
         COALESCE((SELECT sum(quantite) FROM public.stocks_depots sd WHERE sd.produit_id = p.produit_id), 0), 0
  FROM public.produits p WHERE p.actif IS NOT FALSE;

  RETURN QUERY SELECT * FROM public.inventaires WHERE inventaire_id = v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.valider_inventaire_physique(_inventaire_id uuid, _lignes jsonb)
RETURNS SETOF public.inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ligne jsonb; v_ecart_total numeric := 0; v_ecart numeric;
BEGIN
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
END; $$;

CREATE OR REPLACE FUNCTION public.regulariser_inventaire(_inventaire_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_depot uuid; r record;
BEGIN
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
END; $$;

-- ---------- Retours / Specimens (stubs best-effort) -----------------
CREATE OR REPLACE FUNCTION public.get_lignes_retournables(_commande_id uuid)
RETURNS TABLE(produit_id uuid, designation text, reference_produit text, quantite_disponible numeric, prix_unitaire numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT produit_id, designation, reference_produit, quantite::numeric, prix_unitaire
  FROM public.commande_lignes WHERE commande_id = _commande_id;
$$;

CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
RETURNS SETOF public.retours LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_ref text := public._next_ref('RET','public.retours','reference'); v_l jsonb;
BEGIN
  INSERT INTO public.retours(reference, commande_id, client_id, client_nom, date_retour, statut, motif, notes)
  VALUES (v_ref,
    NULLIF(_payload->>'commande_id','')::uuid,
    NULLIF(_payload->>'client_id','')::uuid,
    _payload->>'client_nom',
    COALESCE((_payload->>'date_retour')::date, current_date),
    'brouillon',
    _payload->>'motif',
    _payload->>'notes')
  RETURNING retour_id INTO v_id;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.retour_lignes(retour_id, produit_id, designation, quantite, prix_unitaire, total_ligne, motif)
    VALUES (v_id,
      NULLIF(v_l->>'produit_id','')::uuid,
      v_l->>'designation',
      COALESCE((v_l->>'quantite')::numeric,0),
      COALESCE((v_l->>'prix_unitaire')::numeric,0),
      COALESCE((v_l->>'quantite')::numeric,0) * COALESCE((v_l->>'prix_unitaire')::numeric,0),
      v_l->>'motif');
  END LOOP;
  RETURN QUERY SELECT * FROM public.retours WHERE retour_id = v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.annuler_retour(_retour_id uuid, _motif text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.retours SET statut = 'annule', notes = COALESCE(_motif, notes)
   WHERE retour_id = _retour_id;
END; $$;

CREATE OR REPLACE FUNCTION public.creer_specimen(_payload jsonb)
RETURNS SETOF public.specimens LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_ref text := public._next_ref('SPC','public.specimens','reference');
BEGIN
  INSERT INTO public.specimens(reference, client_id, client_nom, produit_id, designation, quantite, date_envoi, statut, notes)
  VALUES (v_ref,
    NULLIF(_payload->>'client_id','')::uuid,
    _payload->>'client_nom',
    NULLIF(_payload->>'produit_id','')::uuid,
    _payload->>'designation',
    COALESCE((_payload->>'quantite')::numeric,1),
    COALESCE((_payload->>'date_envoi')::date, current_date),
    'envoye',
    _payload->>'notes')
  RETURNING specimen_id INTO v_id;
  RETURN QUERY SELECT * FROM public.specimens WHERE specimen_id = v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.annuler_specimen(_specimen_id uuid, _motif text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.specimens SET statut = 'annule', notes = COALESCE(_motif, notes)
   WHERE specimen_id = _specimen_id;
END; $$;

-- ---------- Stock reports (stubs) -----------------------------------
CREATE OR REPLACE FUNCTION public.report_stock_ecarts()
RETURNS TABLE(produit_id uuid, designation text, ecart numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT il.produit_id, il.designation, il.ecart
  FROM public.inventaire_lignes il WHERE il.ecart <> 0 ORDER BY abs(il.ecart) DESC LIMIT 500;
$$;

CREATE OR REPLACE FUNCTION public.audit_stock_anomalies()
RETURNS TABLE(type text, produit_id uuid, depot_id uuid, quantite numeric, detail text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT 'stock_negatif'::text, sd.produit_id, sd.depot_id, sd.quantite, 'Stock négatif'::text
  FROM public.stocks_depots sd WHERE sd.quantite < 0 LIMIT 500;
$$;
