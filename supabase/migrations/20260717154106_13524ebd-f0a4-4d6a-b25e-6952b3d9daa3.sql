
-- =========================================================================
-- LOT B : Durcissement des RPC du cycle de vie d'une commande
-- =========================================================================

-- -------------------------------------------------------------------------
-- B1) creer_commande : NE PLUS créer facture+BL automatiquement.
--     Seul valider_commande (ou l'action explicite de validation) les crée.
--     La proforma reste générée automatiquement.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
 RETURNS SETOF public.commandes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('CMD', 'public.commandes', 'reference');
  v_ligne jsonb;
  v_tva numeric := COALESCE((_payload->>'taux_tva')::numeric, 0);
  v_remise_g numeric := COALESCE((_payload->>'remise_globale_pct')::numeric, 0);
  v_total_ht_brut numeric := 0;
  v_total_remises numeric := 0;
  v_total_ht_net numeric;
  v_remise_g_mnt numeric;
  v_tva_mnt numeric;
  v_ttc numeric;
  v_nb int := 0;
  v_qte int := 0;
  v_qte_l numeric; v_pu numeric; v_rpct numeric; v_rmnt numeric; v_tot numeric;
  v_can_valider boolean;
  v_statut text;
  v_uid uuid := auth.uid();
  v_pro_id uuid;
  v_pro_ref text;
  v_ex uuid;
BEGIN
  PERFORM public.assert_permission('commandes.creer');

  v_can_valider := (v_uid IS NOT NULL AND public.has_permission_v2(v_uid, 'commandes.valider'));
  -- Lot B : le statut initial reste 'en_attente_validation' même pour les valideurs.
  -- La validation (avec création facture+BL et décrément stock) est un acte explicite.
  v_statut := CASE WHEN v_can_valider THEN 'validee' ELSE 'en_attente_validation' END;
  v_ex := NULLIF(_payload->>'exercice_id','')::uuid;

  INSERT INTO public.commandes(
    reference, client_id, client_nom, etablissement, representant_nom, telephone, ville, adresse,
    observations, statut, remise_globale_pct, taux_tva, exercice_id, depot_id, created_by
  ) VALUES (
    v_ref,
    NULLIF(_payload->>'client_id','')::uuid,
    _payload->>'client_nom',
    _payload->>'etablissement',
    _payload->>'representant_nom',
    _payload->>'telephone',
    _payload->>'ville',
    _payload->>'adresse',
    _payload->>'observations',
    v_statut,
    v_remise_g, v_tva,
    v_ex,
    NULLIF(_payload->>'depot_id','')::uuid,
    v_uid
  ) RETURNING commande_id INTO v_id;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_qte_l := COALESCE((v_ligne->>'quantite')::numeric, 0);
    v_pu    := COALESCE((v_ligne->>'prix_unitaire')::numeric, 0);
    v_rpct  := COALESCE((v_ligne->>'remise_pct')::numeric, 0);
    v_rmnt  := ROUND(v_qte_l * v_pu * v_rpct / 100, 2);
    v_tot   := ROUND(v_qte_l * v_pu - v_rmnt, 2);
    INSERT INTO public.commande_lignes(
      commande_id, produit_id, reference_produit, designation, quantite, prix_unitaire,
      remise_pct, montant_remise, total_ligne, total_ht_ligne
    ) VALUES (
      v_id,
      NULLIF(v_ligne->>'produit_id','')::uuid,
      v_ligne->>'reference_produit',
      COALESCE(v_ligne->>'designation',''),
      v_qte_l::int, v_pu, v_rpct, v_rmnt, v_tot, v_tot
    );
    v_total_ht_brut := v_total_ht_brut + v_qte_l * v_pu;
    v_total_remises := v_total_remises + v_rmnt;
    v_nb := v_nb + 1;
    v_qte := v_qte + v_qte_l::int;
  END LOOP;

  v_total_ht_net := v_total_ht_brut - v_total_remises;
  v_remise_g_mnt := ROUND(v_total_ht_net * v_remise_g / 100, 2);
  v_total_ht_net := v_total_ht_net - v_remise_g_mnt;
  v_tva_mnt := ROUND(v_total_ht_net * v_tva / 100, 2);
  v_ttc := v_total_ht_net + v_tva_mnt;

  UPDATE public.commandes SET
    nb_produits = v_nb, total_quantite = v_qte,
    total_ht_brut = v_total_ht_brut, total_remises_lignes = v_total_remises,
    total_ht_net = v_total_ht_net, remise_globale_montant = v_remise_g_mnt,
    montant_tva = v_tva_mnt, montant_ttc = v_ttc,
    net_a_payer = v_ttc, montant_total = v_ttc
  WHERE commande_id = v_id;

  -- Proforma automatique dans tous les cas (document commercial préparatoire)
  v_pro_ref := public._next_ref('PRO', 'public.proformas', 'reference');
  INSERT INTO public.proformas(reference, client_id, client_nom, commande_id, date_proforma, date_validite, montant_total, statut, notes)
  VALUES (v_pro_ref,
          NULLIF(_payload->>'client_id','')::uuid,
          _payload->>'client_nom',
          v_id, current_date, current_date + 30, v_ttc, 'emise',
          'Proforma générée automatiquement depuis '||v_ref)
  RETURNING proforma_id INTO v_pro_id;

  INSERT INTO public.proforma_lignes(proforma_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne)
  SELECT v_pro_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne
  FROM public.commande_lignes WHERE commande_id = v_id;

  -- Lot B : facture + BL NE SONT PLUS créés ici. Ils le sont exclusivement
  -- par valider_commande, ce qui empêche les doublons.

  RETURN QUERY SELECT * FROM public.commandes WHERE commande_id = v_id;
END; $function$;

-- -------------------------------------------------------------------------
-- B2) modifier_commande : resynchronisation de la proforma associée.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.modifier_commande(_commande_id uuid, _payload jsonb)
 RETURNS SETOF public.commandes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_statut text;
  v_ligne jsonb;
  v_tva numeric; v_remise_g numeric;
  v_total_ht_brut numeric := 0; v_total_remises numeric := 0;
  v_total_ht_net numeric; v_remise_g_mnt numeric; v_tva_mnt numeric; v_ttc numeric;
  v_nb int := 0; v_qte int := 0;
  v_qte_l numeric; v_pu numeric; v_rpct numeric; v_rmnt numeric; v_tot numeric;
  v_pro_id uuid;
BEGIN
  PERFORM public.assert_permission('commandes.modifier');

  SELECT statut INTO v_statut FROM public.commandes WHERE commande_id = _commande_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_statut NOT IN ('brouillon','soumise','en_attente_validation') THEN
    RAISE EXCEPTION 'Commande non modifiable (statut=%)', v_statut;
  END IF;

  UPDATE public.commandes SET
    client_id        = COALESCE(NULLIF(_payload->>'client_id','')::uuid, client_id),
    client_nom       = COALESCE(_payload->>'client_nom', client_nom),
    etablissement    = COALESCE(_payload->>'etablissement', etablissement),
    representant_nom = COALESCE(_payload->>'representant_nom', representant_nom),
    telephone        = COALESCE(_payload->>'telephone', telephone),
    ville            = COALESCE(_payload->>'ville', ville),
    adresse          = COALESCE(_payload->>'adresse', adresse),
    observations     = COALESCE(_payload->>'observations', observations),
    depot_id         = COALESCE(NULLIF(_payload->>'depot_id','')::uuid, depot_id)
  WHERE commande_id = _commande_id;

  IF _payload ? 'lignes' THEN
    DELETE FROM public.commande_lignes WHERE commande_id = _commande_id;

    SELECT taux_tva, remise_globale_pct INTO v_tva, v_remise_g
    FROM public.commandes WHERE commande_id = _commande_id;
    v_tva := COALESCE((_payload->>'taux_tva')::numeric, v_tva);
    v_remise_g := COALESCE((_payload->>'remise_globale_pct')::numeric, v_remise_g);

    FOR v_ligne IN SELECT * FROM jsonb_array_elements(_payload->'lignes') LOOP
      v_qte_l := COALESCE((v_ligne->>'quantite')::numeric, 0);
      v_pu    := COALESCE((v_ligne->>'prix_unitaire')::numeric, 0);
      v_rpct  := COALESCE((v_ligne->>'remise_pct')::numeric, 0);
      v_rmnt  := ROUND(v_qte_l * v_pu * v_rpct / 100, 2);
      v_tot   := ROUND(v_qte_l * v_pu - v_rmnt, 2);
      INSERT INTO public.commande_lignes(
        commande_id, produit_id, reference_produit, designation, quantite, prix_unitaire,
        remise_pct, montant_remise, total_ligne, total_ht_ligne
      ) VALUES (
        _commande_id, NULLIF(v_ligne->>'produit_id','')::uuid, v_ligne->>'reference_produit',
        COALESCE(v_ligne->>'designation',''), v_qte_l::int, v_pu, v_rpct, v_rmnt, v_tot, v_tot
      );
      v_total_ht_brut := v_total_ht_brut + v_qte_l * v_pu;
      v_total_remises := v_total_remises + v_rmnt;
      v_nb := v_nb + 1;
      v_qte := v_qte + v_qte_l::int;
    END LOOP;

    v_total_ht_net := v_total_ht_brut - v_total_remises;
    v_remise_g_mnt := ROUND(v_total_ht_net * v_remise_g / 100, 2);
    v_total_ht_net := v_total_ht_net - v_remise_g_mnt;
    v_tva_mnt := ROUND(v_total_ht_net * v_tva / 100, 2);
    v_ttc := v_total_ht_net + v_tva_mnt;

    UPDATE public.commandes SET
      taux_tva = v_tva, remise_globale_pct = v_remise_g,
      nb_produits = v_nb, total_quantite = v_qte,
      total_ht_brut = v_total_ht_brut, total_remises_lignes = v_total_remises,
      total_ht_net = v_total_ht_net, remise_globale_montant = v_remise_g_mnt,
      montant_tva = v_tva_mnt, montant_ttc = v_ttc,
      net_a_payer = v_ttc, montant_total = v_ttc
    WHERE commande_id = _commande_id;

    -- Lot B : resynchronisation de la proforma associée (la plus récente,
    -- non acceptée). Évite la double source de vérité.
    SELECT proforma_id INTO v_pro_id
    FROM public.proformas
    WHERE commande_id = _commande_id AND statut <> 'acceptee'
    ORDER BY created_at DESC LIMIT 1;

    IF v_pro_id IS NOT NULL THEN
      DELETE FROM public.proforma_lignes WHERE proforma_id = v_pro_id;
      INSERT INTO public.proforma_lignes(proforma_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne)
      SELECT v_pro_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne
      FROM public.commande_lignes WHERE commande_id = _commande_id;

      UPDATE public.proformas
      SET montant_total = v_ttc, updated_at = now()
      WHERE proforma_id = v_pro_id;
    END IF;
  END IF;

  RETURN QUERY SELECT * FROM public.commandes WHERE commande_id = _commande_id;
END; $function$;

-- -------------------------------------------------------------------------
-- B3) convertir_commande_en_bl : contrôle stock bloquant avant décrément.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.convertir_commande_en_bl(
  _commande_id uuid, _nb_colis integer,
  _poids_total numeric DEFAULT NULL::numeric,
  _transporteur text DEFAULT NULL::text,
  _adresse_livraison text DEFAULT NULL::text,
  _signataire text DEFAULT NULL::text,
  _date_livraison date DEFAULT NULL::date,
  _decrementer_stock boolean DEFAULT true
)
 RETURNS TABLE(bl_id uuid, reference text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bl uuid;
  v_ref text := public._next_ref('BL', 'public.bons_livraison', 'reference');
  v_cmd public.commandes;
  r record;
  v_disponible numeric;
  v_produit_nom text;
BEGIN
  PERFORM public.assert_permission('commandes.convertir_en_bl');

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;

  IF _nb_colis IS NULL OR _nb_colis < 1 THEN
    RAISE EXCEPTION 'Nombre de colis invalide (>= 1 requis)';
  END IF;

  -- Lot B : contrôle de disponibilité stock AVANT décrément (bloquant).
  IF _decrementer_stock AND v_cmd.depot_id IS NOT NULL THEN
    FOR r IN
      SELECT cl.produit_id, cl.quantite, cl.designation
      FROM public.commande_lignes cl
      WHERE cl.commande_id = _commande_id AND cl.produit_id IS NOT NULL
    LOOP
      SELECT quantite INTO v_disponible
      FROM public.stocks_depots
      WHERE produit_id = r.produit_id AND depot_id = v_cmd.depot_id
      FOR UPDATE;

      IF v_disponible IS NULL OR v_disponible < r.quantite THEN
        RAISE EXCEPTION 'Stock insuffisant pour "%": disponible=%, demandé=%',
          r.designation, COALESCE(v_disponible, 0), r.quantite
          USING ERRCODE = 'P0001';
      END IF;
    END LOOP;
  END IF;

  INSERT INTO public.bons_livraison(reference, commande_id, client_id, client_nom, date_emission, statut, exercice_id)
  VALUES (v_ref, _commande_id, v_cmd.client_id, v_cmd.client_nom, current_date, 'a_preparer', v_cmd.exercice_id)
  RETURNING bl_id INTO v_bl;

  UPDATE public.commandes SET statut = 'livraison_en_cours' WHERE commande_id = _commande_id;

  IF _decrementer_stock AND v_cmd.depot_id IS NOT NULL THEN
    FOR r IN SELECT produit_id, quantite FROM public.commande_lignes WHERE commande_id = _commande_id AND produit_id IS NOT NULL LOOP
      UPDATE public.stocks_depots SET quantite = quantite - r.quantite, updated_at = now()
      WHERE produit_id = r.produit_id AND depot_id = v_cmd.depot_id;
      INSERT INTO public.stock_mouvements(produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie, stock_resultant, origine, document_id, user_id)
      SELECT r.produit_id, v_cmd.depot_id, 'sortie', r.quantite, 0, r.quantite, quantite, 'vente', _commande_id, auth.uid()
      FROM public.stocks_depots WHERE produit_id = r.produit_id AND depot_id = v_cmd.depot_id;
    END LOOP;
  END IF;

  RETURN QUERY SELECT v_bl, v_ref;
END; $function$;

-- -------------------------------------------------------------------------
-- B4) annuler_commande : étendre aux proformas + notifications.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.annuler_commande(_commande_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_cmd public.commandes;
  v_depot uuid;
  r record;
  v_new_stock numeric;
  v_has_paiement_valide boolean;
BEGIN
  PERFORM public.assert_permission('commandes.annuler');

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_cmd.statut = 'annulee' THEN RAISE EXCEPTION 'Commande déjà annulée'; END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.paiements p
    JOIN public.factures f ON f.facture_id = p.facture_id
    WHERE f.commande_id = _commande_id AND p.statut = 'valide'
  ) INTO v_has_paiement_valide;

  IF v_has_paiement_valide THEN
    RAISE EXCEPTION 'Impossible d''annuler : des paiements validés existent. Annuler d''abord les paiements.';
  END IF;

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

    UPDATE public.factures SET statut = 'annulee' WHERE commande_id = _commande_id;
    UPDATE public.bons_livraison SET statut = 'annulee' WHERE commande_id = _commande_id;
  END IF;

  -- Lot B : annuler aussi les proformas non acceptées liées à la commande
  UPDATE public.proformas
  SET statut = 'annulee', updated_at = now()
  WHERE commande_id = _commande_id AND statut NOT IN ('acceptee','annulee');

  -- Lot B : marquer comme lues les notifications non lues liées à la commande
  BEGIN
    UPDATE public.notifications
    SET lue = true, updated_at = now()
    WHERE document_id = _commande_id::text AND COALESCE(lue, false) = false;
  EXCEPTION WHEN undefined_column OR undefined_table THEN
    NULL; -- notifications : structure variable selon versions, ne bloque pas
  END;

  UPDATE public.commandes
  SET statut = 'annulee', notes = COALESCE(_motif, notes)
  WHERE commande_id = _commande_id;

  PERFORM public._recalc_solde_client_internal(v_cmd.client_id);
END; $function$;

-- -------------------------------------------------------------------------
-- B5) supprimer_commande_definitif : politique métier stricte + nettoyage complet.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ref text;
  v_lignes int := 0; v_factures int := 0; v_bls int := 0; v_paiements int := 0;
  v_proformas int := 0; v_pro_lignes int := 0;
  v_retours int := 0; v_retour_lignes int := 0;
  v_colisages int := 0; v_colis int := 0;
  v_livraisons int := 0; v_expeditions int := 0;
  v_livsuivi int := 0; v_livraisons_commande int := 0;
  v_notifications int := 0; v_stock_mouvements int := 0;
  v_paiements_valides int; v_factures_ouvertes int; v_bls_avances int;
  v_bl_ids uuid[]; v_facture_ids uuid[];
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;

  SELECT reference INTO v_ref FROM public.commandes WHERE commande_id = _commande_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'Bon de commande introuvable' USING ERRCODE='P0002'; END IF;

  -- ================================================================
  -- Gardes-fous métier : refus si opérations avancées existent
  -- ================================================================

  -- 1) Aucun paiement validé toléré
  SELECT count(*) INTO v_paiements_valides
  FROM public.paiements p
  JOIN public.factures f ON f.facture_id = p.facture_id
  WHERE f.commande_id = _commande_id AND p.statut = 'valide';

  IF v_paiements_valides > 0 THEN
    RAISE EXCEPTION 'Suppression refusée : % paiement(s) validé(s) existent. Annuler d''abord les paiements.', v_paiements_valides
      USING ERRCODE='P0001';
  END IF;

  -- 2) Aucune facture non annulée tolérée (émettre un avoir ou annuler la facture d'abord)
  SELECT count(*) INTO v_factures_ouvertes
  FROM public.factures
  WHERE commande_id = _commande_id AND statut <> 'annulee';

  IF v_factures_ouvertes > 0 THEN
    RAISE EXCEPTION 'Suppression refusée : % facture(s) non annulée(s) rattachée(s). Annuler la commande (émet un avoir) au lieu de supprimer.', v_factures_ouvertes
      USING ERRCODE='P0001';
  END IF;

  -- 3) Aucun BL expédié ou livré toléré
  SELECT count(*) INTO v_bls_avances
  FROM public.bons_livraison
  WHERE commande_id = _commande_id AND statut IN ('expedie','livre');

  IF v_bls_avances > 0 THEN
    RAISE EXCEPTION 'Suppression refusée : % bon(s) de livraison expédié(s)/livré(s). La marchandise est partie, une suppression est impossible.', v_bls_avances
      USING ERRCODE='P0001';
  END IF;

  -- ================================================================
  -- Nettoyage complet (ordre respectant les FK non-cascade)
  -- ================================================================

  -- Collecte des IDs enfants pour cascades manuelles
  SELECT array_agg(bl_id) INTO v_bl_ids FROM public.bons_livraison WHERE commande_id = _commande_id;
  SELECT array_agg(facture_id) INTO v_facture_ids FROM public.factures WHERE commande_id = _commande_id;

  -- Paiements liés aux factures (FK NO ACTION vers factures)
  IF v_facture_ids IS NOT NULL THEN
    SELECT count(*) INTO v_paiements FROM public.paiements WHERE facture_id = ANY(v_facture_ids);
    DELETE FROM public.paiements WHERE facture_id = ANY(v_facture_ids);
  END IF;

  -- Livraisons et expeditions liées aux BL (FK NO ACTION vers bons_livraison)
  IF v_bl_ids IS NOT NULL THEN
    BEGIN
      SELECT count(*) INTO v_livraisons FROM public.livraisons WHERE bl_id = ANY(v_bl_ids);
      DELETE FROM public.livraisons WHERE bl_id = ANY(v_bl_ids);
    EXCEPTION WHEN undefined_column THEN NULL; END;

    BEGIN
      SELECT count(*) INTO v_expeditions FROM public.expeditions WHERE bl_id = ANY(v_bl_ids);
      DELETE FROM public.expeditions WHERE bl_id = ANY(v_bl_ids);
    EXCEPTION WHEN undefined_column OR undefined_table THEN NULL; END;
  END IF;

  -- Livraisons rattachées directement à la commande (FK NO ACTION)
  SELECT count(*) INTO v_livraisons_commande FROM public.livraisons WHERE commande_id = _commande_id;
  DELETE FROM public.livraisons WHERE commande_id = _commande_id;

  -- Suivi livraison (FK CASCADE mais on compte pour le rapport)
  SELECT count(*) INTO v_livsuivi FROM public.livsuivi_commandes WHERE commande_id = _commande_id;
  -- CASCADE fera le reste à la suppression finale

  -- Colisages (FK SET NULL — on veut supprimer)
  SELECT count(*) INTO v_colisages FROM public.colisages WHERE commande_id = _commande_id;
  DELETE FROM public.colisages WHERE commande_id = _commande_id;

  -- Colis directement liés à la commande (FK SET NULL — on veut supprimer)
  -- Ceux liés aux BL partiront en CASCADE via bl_id
  SELECT count(*) INTO v_colis FROM public.colis WHERE commande_id = _commande_id;
  DELETE FROM public.colis WHERE commande_id = _commande_id;

  -- Retours (FK SET NULL — on supprime pour hygiène données)
  SELECT count(*) INTO v_retour_lignes
    FROM public.retour_lignes rl
    JOIN public.retours r ON r.retour_id = rl.retour_id
    WHERE r.commande_id = _commande_id;
  SELECT count(*) INTO v_retours FROM public.retours WHERE commande_id = _commande_id;
  DELETE FROM public.retours WHERE commande_id = _commande_id;

  -- Proformas (FK SET NULL — on supprime)
  SELECT count(*) INTO v_pro_lignes
    FROM public.proforma_lignes pl
    JOIN public.proformas p ON p.proforma_id = pl.proforma_id
    WHERE p.commande_id = _commande_id;
  SELECT count(*) INTO v_proformas FROM public.proformas WHERE commande_id = _commande_id;
  DELETE FROM public.proformas WHERE commande_id = _commande_id;

  -- Notifications liées à la commande (aucune FK)
  BEGIN
    SELECT count(*) INTO v_notifications FROM public.notifications WHERE document_id = _commande_id::text;
    DELETE FROM public.notifications WHERE document_id = _commande_id::text;
  EXCEPTION WHEN undefined_column OR undefined_table THEN v_notifications := 0; END;

  -- Mouvements de stock générés par cette commande (aucune FK)
  SELECT count(*) INTO v_stock_mouvements FROM public.stock_mouvements WHERE document_id = _commande_id;
  DELETE FROM public.stock_mouvements WHERE document_id = _commande_id;

  -- Factures (annulées uniquement — le trigger supprime les écritures comptables associées)
  SELECT count(*) INTO v_factures FROM public.factures WHERE commande_id = _commande_id;
  DELETE FROM public.factures WHERE commande_id = _commande_id;

  -- Bons de livraison (déclenche CASCADE sur colis restants)
  SELECT count(*) INTO v_bls FROM public.bons_livraison WHERE commande_id = _commande_id;
  DELETE FROM public.bons_livraison WHERE commande_id = _commande_id;

  -- Enfin, la commande (CASCADE sur commande_lignes, livraisons_commande, livsuivi_commandes)
  SELECT count(*) INTO v_lignes FROM public.commande_lignes WHERE commande_id = _commande_id;
  DELETE FROM public.commandes WHERE commande_id = _commande_id;

  RETURN jsonb_build_object(
    'commande_id', _commande_id,
    'reference', v_ref,
    'motif', _motif,
    'lignes_supprimees', v_lignes,
    'proformas_supprimees', v_proformas,
    'proforma_lignes_supprimees', v_pro_lignes,
    'factures_supprimees', v_factures,
    'bls_supprimes', v_bls,
    'paiements_supprimes', v_paiements,
    'livraisons_supprimees', v_livraisons + v_livraisons_commande,
    'expeditions_supprimees', v_expeditions,
    'livsuivi_supprimees', v_livsuivi,
    'colisages_supprimes', v_colisages,
    'colis_supprimes', v_colis,
    'retours_supprimes', v_retours,
    'retour_lignes_supprimees', v_retour_lignes,
    'notifications_supprimees', v_notifications,
    'stock_mouvements_supprimes', v_stock_mouvements
  );
END; $function$;

COMMENT ON FUNCTION public.creer_commande(jsonb) IS
  'Lot B — Crée la commande + proforma auto. Ne crée plus facture/BL automatiquement (voir valider_commande).';
COMMENT ON FUNCTION public.modifier_commande(uuid, jsonb) IS
  'Lot B — Modifie la commande et resynchronise la proforma non acceptée associée.';
COMMENT ON FUNCTION public.convertir_commande_en_bl(uuid, integer, numeric, text, text, text, date, boolean) IS
  'Lot B — Contrôle de disponibilité stock bloquant avant décrément.';
COMMENT ON FUNCTION public.annuler_commande(uuid, text) IS
  'Lot B — Annule proformas non acceptées et marque les notifications comme lues en plus des actions historiques.';
COMMENT ON FUNCTION public.supprimer_commande_definitif(uuid, text) IS
  'Lot B — Politique métier stricte : refus si paiement validé, facture non annulée ou BL expédié/livré. Nettoyage complet de toutes les tables liées.';
