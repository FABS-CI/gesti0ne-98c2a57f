-- =====================================================================
-- LOT 5 : Fonction interne recalcul solde (sans check permission)
-- =====================================================================
CREATE OR REPLACE FUNCTION public._recalc_solde_client_internal(_client_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_solde numeric;
BEGIN
  IF _client_id IS NULL THEN RETURN 0; END IF;
  SELECT COALESCE(sum(montant_total - COALESCE(montant_paye,0)), 0) INTO v_solde
  FROM public.factures
  WHERE client_id = _client_id AND statut IN ('impayee','partielle');
  UPDATE public.clients SET solde = v_solde WHERE client_id = _client_id;
  RETURN v_solde;
END; $$;
REVOKE ALL ON FUNCTION public._recalc_solde_client_internal(uuid) FROM public, anon, authenticated;

-- =====================================================================
-- LOT 4 : valider_commande — ajoute décrément stock + recalc solde
-- =====================================================================
CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
RETURNS TABLE(facture_reference text, bl_reference text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_cmd public.commandes;
  v_f_ref text := public._next_ref('FAC', 'public.factures', 'reference');
  v_bl_ref text := public._next_ref('BL', 'public.bons_livraison', 'reference');
  v_bl_id uuid;
  v_depot uuid;
  r record;
  v_dispo numeric;
  v_new_stock numeric;
BEGIN
  PERFORM public.assert_permission('commandes.valider');

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_cmd.statut = 'validee' THEN RAISE EXCEPTION 'Commande déjà validée'; END IF;
  IF v_cmd.statut = 'annulee' THEN RAISE EXCEPTION 'Commande annulée, impossible à valider'; END IF;

  -- Dépôt : commande.depot_id sinon dépôt principal
  v_depot := v_cmd.depot_id;
  IF v_depot IS NULL THEN
    SELECT depot_id INTO v_depot FROM public.depots WHERE is_principal = true LIMIT 1;
  END IF;
  IF v_depot IS NULL THEN
    RAISE EXCEPTION 'Aucun dépôt défini (ni sur la commande, ni comme dépôt principal)';
  END IF;

  -- 1) Décrément stock ligne par ligne (blocage si insuffisant)
  FOR r IN
    SELECT cl.produit_id, cl.quantite, cl.designation
    FROM public.commande_lignes cl
    WHERE cl.commande_id = _commande_id AND cl.produit_id IS NOT NULL
  LOOP
    -- Vérifier dispo
    SELECT quantite INTO v_dispo
    FROM public.stocks_depots
    WHERE produit_id = r.produit_id AND depot_id = v_depot
    FOR UPDATE;

    v_dispo := COALESCE(v_dispo, 0);
    IF v_dispo < r.quantite THEN
      RAISE EXCEPTION 'Stock insuffisant pour "%": disponible %, demandé %',
        r.designation, v_dispo, r.quantite USING ERRCODE = 'P0001';
    END IF;

    v_new_stock := v_dispo - r.quantite;

    UPDATE public.stocks_depots
    SET quantite = v_new_stock, updated_at = now()
    WHERE produit_id = r.produit_id AND depot_id = v_depot;

    INSERT INTO public.stock_mouvements(
      produit_id, depot_id, type, quantite,
      quantite_entree, quantite_sortie, stock_resultant,
      origine, document_id, document_reference, document_table,
      user_id, motif
    ) VALUES (
      r.produit_id, v_depot, 'sortie', r.quantite,
      0, r.quantite, v_new_stock,
      'vente', _commande_id, v_cmd.reference, 'commandes',
      auth.uid(), 'Validation commande ' || COALESCE(v_cmd.reference,'')
    );
  END LOOP;

  -- 2) Facture + BL
  INSERT INTO public.factures(
    reference, client_id, client_nom, commande_id, exercice_id,
    date_facture, date_echeance, montant_total, statut
  ) VALUES (
    v_f_ref, v_cmd.client_id, v_cmd.client_nom, _commande_id, v_cmd.exercice_id,
    current_date, current_date + 30, v_cmd.montant_total, 'impayee'
  );

  INSERT INTO public.bons_livraison(
    reference, commande_id, client_id, client_nom, date_emission, statut, exercice_id
  ) VALUES (
    v_bl_ref, _commande_id, v_cmd.client_id, v_cmd.client_nom, current_date, 'a_preparer', v_cmd.exercice_id
  ) RETURNING bl_id INTO v_bl_id;

  UPDATE public.commandes SET statut = 'validee' WHERE commande_id = _commande_id;

  -- 3) Recalc solde client (nouvelle créance)
  PERFORM public._recalc_solde_client_internal(v_cmd.client_id);

  RETURN QUERY SELECT v_f_ref, v_bl_ref;
END; $$;

-- =====================================================================
-- LOT 4bis : annuler_commande — remet le stock et annule facture+BL
-- =====================================================================
CREATE OR REPLACE FUNCTION public.annuler_commande(_commande_id uuid, _motif text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_cmd public.commandes;
  v_depot uuid;
  r record;
  v_stock numeric;
  v_new_stock numeric;
  v_has_paiement_valide boolean;
BEGIN
  PERFORM public.assert_permission('commandes.annuler');

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_cmd.statut = 'annulee' THEN RAISE EXCEPTION 'Commande déjà annulée'; END IF;

  -- Empêcher l'annulation si des paiements valides existent
  SELECT EXISTS(
    SELECT 1 FROM public.paiements p
    JOIN public.factures f ON f.facture_id = p.facture_id
    WHERE f.commande_id = _commande_id AND p.statut = 'valide'
  ) INTO v_has_paiement_valide;

  IF v_has_paiement_valide THEN
    RAISE EXCEPTION 'Impossible d''annuler : des paiements validés existent. Annuler d''abord les paiements.';
  END IF;

  -- Si la commande était validée, remettre le stock
  IF v_cmd.statut = 'validee' THEN
    v_depot := v_cmd.depot_id;
    IF v_depot IS NULL THEN
      SELECT depot_id INTO v_depot FROM public.depots WHERE is_principal = true LIMIT 1;
    END IF;

    IF v_depot IS NOT NULL THEN
      FOR r IN
        SELECT cl.produit_id, cl.quantite
        FROM public.commande_lignes cl
        WHERE cl.commande_id = _commande_id AND cl.produit_id IS NOT NULL
      LOOP
        INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
        VALUES (r.produit_id, v_depot, r.quantite)
        ON CONFLICT (produit_id, depot_id) DO UPDATE
          SET quantite = public.stocks_depots.quantite + EXCLUDED.quantite,
              updated_at = now();

        SELECT quantite INTO v_new_stock FROM public.stocks_depots
        WHERE produit_id = r.produit_id AND depot_id = v_depot;

        INSERT INTO public.stock_mouvements(
          produit_id, depot_id, type, quantite,
          quantite_entree, quantite_sortie, stock_resultant,
          origine, document_id, document_reference, document_table,
          user_id, motif
        ) VALUES (
          r.produit_id, v_depot, 'entree', r.quantite,
          r.quantite, 0, v_new_stock,
          'annulation_commande', _commande_id, v_cmd.reference, 'commandes',
          auth.uid(), COALESCE(_motif, 'Annulation commande')
        );
      END LOOP;
    END IF;

    -- Annuler facture + BL liés
    UPDATE public.factures SET statut = 'annulee' WHERE commande_id = _commande_id;
    UPDATE public.bons_livraison SET statut = 'annule' WHERE commande_id = _commande_id;
  END IF;

  UPDATE public.commandes
  SET statut = 'annulee', notes = COALESCE(_motif, notes)
  WHERE commande_id = _commande_id;

  -- Recalc solde (créance annulée)
  PERFORM public._recalc_solde_client_internal(v_cmd.client_id);
END; $$;
REVOKE ALL ON FUNCTION public.annuler_commande(uuid,text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.annuler_commande(uuid,text) TO authenticated;

-- =====================================================================
-- LOT 5 : Ajout recalc solde dans les RPC paiement
-- =====================================================================
CREATE OR REPLACE FUNCTION public.enregistrer_paiement(_payload jsonb)
RETURNS SETOF paiements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('PAI', 'public.paiements', 'reference');
  v_facture_id uuid := NULLIF(_payload->>'facture_id','')::uuid;
  v_montant numeric := COALESCE((_payload->>'montant')::numeric, 0);
  v_client_id uuid;
  v_client_nom text;
  v_new_paye numeric; v_total numeric;
  v_date date := COALESCE((_payload->>'date_paiement')::date, current_date);
  v_ex uuid;
BEGIN
  PERFORM public.assert_permission('paiements.creer');

  IF v_facture_id IS NULL THEN RAISE EXCEPTION 'facture_id obligatoire'; END IF;
  SELECT client_id, client_nom, montant_total, montant_paye INTO v_client_id, v_client_nom, v_total, v_new_paye
    FROM public.factures WHERE facture_id = v_facture_id;
  IF v_total IS NULL THEN RAISE EXCEPTION 'Facture introuvable'; END IF;

  v_ex := public._resolve_exercice_id(v_date);
  IF v_ex IS NULL THEN
    SELECT exercice_id INTO v_ex FROM public.exercices_comptables WHERE is_actif ORDER BY date_debut DESC LIMIT 1;
  END IF;

  INSERT INTO public.paiements(
    reference, facture_id, client_nom, date_paiement, montant, mode_paiement,
    statut, notes, reference_paiement, banque, num_transaction, observations, cree_par, exercice_id
  ) VALUES (
    v_ref, v_facture_id, v_client_nom, v_date, v_montant,
    COALESCE(_payload->>'mode_paiement','especes'), 'valide',
    _payload->>'notes', _payload->>'reference_paiement', _payload->>'banque',
    _payload->>'num_transaction', _payload->>'observations', auth.uid(), v_ex
  ) RETURNING paiement_id INTO v_id;

  v_new_paye := COALESCE(v_new_paye,0) + v_montant;
  UPDATE public.factures SET
    montant_paye = v_new_paye,
    statut = CASE WHEN v_new_paye >= v_total THEN 'payee' WHEN v_new_paye > 0 THEN 'partielle' ELSE 'impayee' END
  WHERE facture_id = v_facture_id;

  -- Lot 5 : recalc solde
  PERFORM public._recalc_solde_client_internal(v_client_id);

  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id = v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.valider_paiement(_paiement_id uuid, _commentaire text DEFAULT NULL::text)
RETURNS SETOF paiements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_client_id uuid;
BEGIN
  PERFORM public.assert_permission('paiements.valider');

  UPDATE public.paiements SET statut='valide', valide_par=auth.uid(), valide_le=now(), commentaire_validation=_commentaire
  WHERE paiement_id=_paiement_id AND statut IN ('en_attente','en_attente_validation');
  IF NOT FOUND THEN RAISE EXCEPTION 'Paiement non validable'; END IF;

  SELECT f.client_id INTO v_client_id
  FROM public.paiements p JOIN public.factures f ON f.facture_id = p.facture_id
  WHERE p.paiement_id = _paiement_id;
  PERFORM public._recalc_solde_client_internal(v_client_id);

  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id=_paiement_id;
END; $$;

CREATE OR REPLACE FUNCTION public.annuler_paiement(_paiement_id uuid, _raison text, _notes text DEFAULT NULL::text)
RETURNS SETOF paiements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_row public.paiements;
  v_new_paye numeric;
  v_total numeric;
  v_client_id uuid;
BEGIN
  PERFORM public.assert_permission('paiements.annuler');

  SELECT * INTO v_row FROM public.paiements WHERE paiement_id = _paiement_id;
  IF v_row.paiement_id IS NULL THEN RAISE EXCEPTION 'Paiement introuvable'; END IF;
  IF v_row.statut = 'annule' THEN RAISE EXCEPTION 'Déjà annulé'; END IF;

  INSERT INTO public.paiement_annulations_audit(paiement_id, facture_id, annule_par, raison, notes, montant_annule)
  VALUES (_paiement_id, v_row.facture_id, auth.uid(), COALESCE(_raison,''), _notes, v_row.montant);

  UPDATE public.paiements SET statut = 'annule' WHERE paiement_id = _paiement_id;

  IF v_row.facture_id IS NOT NULL THEN
    SELECT montant_total, GREATEST(COALESCE(montant_paye,0) - v_row.montant, 0), client_id
      INTO v_total, v_new_paye, v_client_id
      FROM public.factures WHERE facture_id = v_row.facture_id;
    UPDATE public.factures SET
      montant_paye = v_new_paye,
      statut = CASE WHEN v_new_paye >= v_total THEN 'payee' WHEN v_new_paye > 0 THEN 'partielle' ELSE 'impayee' END
    WHERE facture_id = v_row.facture_id;

    -- Lot 5 : recalc solde
    PERFORM public._recalc_solde_client_internal(v_client_id);
  END IF;

  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id = _paiement_id;
END; $$;
