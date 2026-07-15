
-- ============================================================================
-- Corrections anomalies audit final : A1 (suppression bloquée), A2 (stock fantôme), A3 (bug cast uuid=text)
-- ============================================================================

-- A1 : supprimer_commande_definitif doit débloquer le trigger no_delete sur stock_mouvements
CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    _is_super_admin boolean;
    _liv_ids uuid[];
    _colis_ids uuid[];
    _bl_ids uuid[];
    _facture_ids uuid[];
    _proforma_ids uuid[];
    _ref text;
    _dates date[];
    _d date;
    _mv record;
BEGIN
    SELECT public.has_role(auth.uid(), 'super_admin'::app_role) INTO _is_super_admin;
    IF NOT _is_super_admin THEN
        RAISE EXCEPTION 'Accès refusé : super_admin uniquement';
    END IF;

    PERFORM set_config('app.allow_paiement_delete', 'on', true);
    -- A1 FIX: autoriser la suppression des stock_mouvements dans cette transaction
    PERFORM set_config('app.allow_stock_mouvement_delete', 'on', true);

    SELECT reference INTO _ref FROM public.commandes WHERE commande_id = _commande_id;
    IF _ref IS NULL THEN
      RAISE EXCEPTION 'Commande introuvable';
    END IF;

    SELECT array_agg(livraison_id) INTO _liv_ids FROM public.livraisons_commande WHERE commande_id = _commande_id;
    SELECT array_agg(colis_id)     INTO _colis_ids FROM public.colis WHERE commande_id = _commande_id;
    SELECT array_agg(bl_id)        INTO _bl_ids FROM public.bons_livraison WHERE commande_id = _commande_id;
    SELECT array_agg(facture_id)   INTO _facture_ids FROM public.factures WHERE commande_id = _commande_id;
    SELECT array_agg(proforma_id)  INTO _proforma_ids FROM public.proformas WHERE commande_id = _commande_id;

    IF _colis_ids IS NOT NULL THEN
      SELECT array_agg(DISTINCT date_colisage::date)
        INTO _dates
      FROM public.colis WHERE colis_id = ANY(_colis_ids);
    END IF;

    IF _colis_ids IS NOT NULL OR _bl_ids IS NOT NULL OR _facture_ids IS NOT NULL THEN
      FOR _mv IN
        SELECT * FROM public.stock_mouvements
        WHERE (document_table = 'colis'          AND document_id = ANY(COALESCE(_colis_ids, '{}'::uuid[])))
           OR (document_table = 'bons_livraison' AND document_id = ANY(COALESCE(_bl_ids,    '{}'::uuid[])))
           OR (document_table = 'factures'       AND document_id = ANY(COALESCE(_facture_ids,'{}'::uuid[])))
           OR (document_table = 'commandes'      AND document_id = _commande_id)
      LOOP
        IF _mv.depot_id IS NOT NULL AND _mv.produit_id IS NOT NULL THEN
          UPDATE public.stocks_depots
             SET quantite = GREATEST(0, quantite + COALESCE(_mv.quantite_sortie,0) - COALESCE(_mv.quantite_entree,0)),
                 updated_at = now()
           WHERE produit_id = _mv.produit_id AND depot_id = _mv.depot_id;
        END IF;
      END LOOP;

      DELETE FROM public.stock_mouvements
      WHERE (document_table = 'colis'          AND document_id = ANY(COALESCE(_colis_ids, '{}'::uuid[])))
         OR (document_table = 'bons_livraison' AND document_id = ANY(COALESCE(_bl_ids,    '{}'::uuid[])))
         OR (document_table = 'factures'       AND document_id = ANY(COALESCE(_facture_ids,'{}'::uuid[])))
         OR (document_table = 'commandes'      AND document_id = _commande_id);
    END IF;

    IF _facture_ids IS NOT NULL THEN
      DELETE FROM public.retour_lignes rl USING public.retours r
        WHERE rl.retour_id = r.retour_id AND r.facture_id = ANY(_facture_ids);
      DELETE FROM public.retours WHERE facture_id = ANY(_facture_ids);
      DELETE FROM public.bons_retour WHERE facture_id = ANY(_facture_ids);
      DELETE FROM public.fne_factures WHERE facture_id = ANY(_facture_ids);
    END IF;
    DELETE FROM public.retour_lignes rl USING public.retours r
      WHERE rl.retour_id = r.retour_id AND r.commande_id = _commande_id;
    DELETE FROM public.retours WHERE commande_id = _commande_id;

    DELETE FROM public.livsuivi_historique lh
      USING public.livsuivi_commandes lc
      WHERE lh.livraison_id = lc.id AND lc.commande_id = _commande_id;
    DELETE FROM public.livsuivi_commandes WHERE commande_id = _commande_id;

    DELETE FROM public.notifications
     WHERE (document_type = 'commande'      AND document_id = _commande_id)
        OR (document_type = 'facture'       AND document_id = ANY(COALESCE(_facture_ids,'{}'::uuid[])))
        OR (document_type = 'bon_livraison' AND document_id = ANY(COALESCE(_bl_ids,    '{}'::uuid[])))
        OR (document_type = 'colis'         AND document_id = ANY(COALESCE(_colis_ids, '{}'::uuid[])))
        OR (document_type = 'proforma'      AND document_id = ANY(COALESCE(_proforma_ids,'{}'::uuid[])));

    DELETE FROM public.historique_envois
     WHERE (document_type = 'commande'      AND document_id = _commande_id)
        OR (document_type = 'facture'       AND document_id = ANY(COALESCE(_facture_ids,'{}'::uuid[])))
        OR (document_type = 'bon_livraison' AND document_id = ANY(COALESCE(_bl_ids,    '{}'::uuid[])))
        OR (document_type = 'colis'         AND document_id = ANY(COALESCE(_colis_ids, '{}'::uuid[])))
        OR (document_type = 'proforma'      AND document_id = ANY(COALESCE(_proforma_ids,'{}'::uuid[])));

    IF _liv_ids IS NOT NULL THEN
        DELETE FROM public.livraison_commande_historique WHERE livraison_id = ANY(_liv_ids);
        DELETE FROM public.livraisons_commande WHERE livraison_id = ANY(_liv_ids);
    END IF;
    IF _colis_ids IS NOT NULL THEN
        DELETE FROM public.colis_statut_historique WHERE colis_id = ANY(_colis_ids);
        DELETE FROM public.colis_lignes WHERE colis_id = ANY(_colis_ids);
        DELETE FROM public.colisage_modifications_historique WHERE colis_id = ANY(_colis_ids);
        DELETE FROM public.colis WHERE colis_id = ANY(_colis_ids);
    END IF;
    IF _bl_ids IS NOT NULL THEN
        DELETE FROM public.bons_livraison WHERE bl_id = ANY(_bl_ids);
    END IF;
    IF _facture_ids IS NOT NULL THEN
        DELETE FROM public.paiements WHERE facture_id = ANY(_facture_ids);
        DELETE FROM public.factures WHERE facture_id = ANY(_facture_ids);
    END IF;
    IF _proforma_ids IS NOT NULL THEN
        DELETE FROM public.proforma_lignes WHERE proforma_id = ANY(_proforma_ids);
        DELETE FROM public.proformas WHERE proforma_id = ANY(_proforma_ids);
    END IF;

    DELETE FROM public.commande_lignes WHERE commande_id = _commande_id;
    DELETE FROM public.commandes WHERE commande_id = _commande_id;

    IF _dates IS NOT NULL THEN
      FOREACH _d IN ARRAY _dates LOOP
        PERFORM public.recalc_tournee_from_colis(_d);
      END LOOP;
    END IF;

    INSERT INTO public.audit_events(action, module, table_name, record_id, record_ref, user_id, metadata, criticite)
    VALUES ('DELETE'::audit_action, 'commandes', 'commandes', _commande_id::text, _ref, auth.uid(),
            jsonb_build_object(
              'motif', _motif,
              'type', 'suppression_definitive',
              'colis_supprimes', COALESCE(array_length(_colis_ids,1),0),
              'bl_supprimes',    COALESCE(array_length(_bl_ids,1),0),
              'factures_supprimees', COALESCE(array_length(_facture_ids,1),0),
              'proformas_supprimees', COALESCE(array_length(_proforma_ids,1),0),
              'tournees_recalculees', COALESCE(array_length(_dates,1),0)
            ),
            'critical'::audit_criticite);
END;
$function$;

-- ============================================================================
-- A2 : annuler_colisage doit réinjecter le stock des colis annulés
--      via des mouvements compensatoires (entrée) sur les sorties liées.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.annuler_colisage(_bl_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bl public.bons_livraison;
  v_user uuid := auth.uid();
  v_email text;
  v_is_admin boolean;
  v_logistique_deja_pris boolean;
  v_dates date[];
  v_d date;
  v_colis_ids uuid[];
  v_mv record;
  v_nb_compensations int := 0;
BEGIN
  PERFORM public.assert_permission('colisage.annuler');
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_bl FROM public.bons_livraison WHERE bl_id = _bl_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bon de livraison introuvable';
  END IF;

  v_is_admin := public.has_role(v_user, 'super_admin'::public.app_role);

  v_logistique_deja_pris := EXISTS (
    SELECT 1 FROM public.colis c
    WHERE c.bl_id = _bl_id
      AND COALESCE(c.statut_logistique, 'prepare') <> 'prepare'
  );

  IF NOT v_is_admin THEN
    IF v_bl.statut NOT IN ('brouillon', 'a_preparer', 'colisage_en_cours') OR v_logistique_deja_pris THEN
      RAISE EXCEPTION 'Impossible d''annuler ce colisage car il est déjà pris en charge par le service logistique.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  SELECT array_agg(DISTINCT date_colisage::date), array_agg(colis_id)
    INTO v_dates, v_colis_ids
  FROM public.colis WHERE bl_id = _bl_id;

  -- A2 FIX: réinjecter le stock via mouvements compensatoires
  IF v_colis_ids IS NOT NULL THEN
    FOR v_mv IN
      SELECT produit_id, depot_id, SUM(COALESCE(quantite_sortie,0)) AS qte_sortie
      FROM public.stock_mouvements
      WHERE document_table = 'colis'
        AND document_id = ANY(v_colis_ids)
        AND COALESCE(quantite_sortie,0) > 0
      GROUP BY produit_id, depot_id
      HAVING SUM(COALESCE(quantite_sortie,0)) > 0
    LOOP
      INSERT INTO public.stock_mouvements(
        produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie,
        origine, document_id, document_table, document_reference,
        motif, user_id, user_nom, observation
      ) VALUES (
        v_mv.produit_id, v_mv.depot_id, 'entree', v_mv.qte_sortie, v_mv.qte_sortie, 0,
        'annulation_colisage', _bl_id, 'bons_livraison', v_bl.reference,
        'Réinjection stock - annulation colisage', v_user,
        COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email', ''),
        COALESCE(_motif, 'Annulation colisage')
      );
      v_nb_compensations := v_nb_compensations + 1;
    END LOOP;
  END IF;

  IF v_bl.commande_id IS NOT NULL THEN
    DELETE FROM public.livsuivi_commandes WHERE commande_id = v_bl.commande_id;
  END IF;

  DELETE FROM public.colis WHERE bl_id = _bl_id;

  UPDATE public.bons_livraison
  SET statut = 'annule',
      annule_at = now(),
      annule_par = v_user,
      annule_par_nom = COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email'),
      annulation_motif = _motif,
      updated_at = now()
  WHERE bl_id = _bl_id;

  IF v_dates IS NOT NULL THEN
    FOREACH v_d IN ARRAY v_dates LOOP
      PERFORM public.recalc_tournee_from_colis(v_d);
    END LOOP;
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user;

  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (
    v_user, COALESCE(v_email, ''), 'colisage_annule', 'bons_livraison', _bl_id::text,
    to_jsonb(v_bl),
    jsonb_build_object('motif', _motif, 'reference', v_bl.reference,
      'role', CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END,
      'tournees_recalculees', COALESCE(array_length(v_dates,1),0),
      'compensations_stock', v_nb_compensations)
  );
END;
$function$;

-- ============================================================================
-- A3 : supprimer_colisage - corriger le cast uuid=text sur notifications.document_id
--      La colonne document_id est de type uuid, il ne faut pas caster _bl_id::text
--      ni utiliser v_colis_ids_text (text[]) sur une colonne uuid.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.supprimer_colisage(_bl_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bl public.bons_livraison;
  v_user uuid := auth.uid();
  v_email text;
  v_is_admin boolean;
  v_owner boolean;
  v_has_colis boolean;
  v_logistique_deja_pris boolean;
  v_colis_ids uuid[];
  v_dates date[];
  v_d date;
  v_nb_colis int := 0;
  v_nb_notifications int := 0;
  v_nb_envois int := 0;
  v_nb_livsuivi int := 0;
  v_nb_livraisons int := 0;
  v_nb_livraisons_cmd int := 0;
  v_nb_expeditions int := 0;
  v_nb_tournees int := 0;
  v_summary jsonb;
BEGIN
  PERFORM public.assert_permission('colisage.supprimer');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000'; END IF;
  SELECT * INTO v_bl FROM public.bons_livraison WHERE bl_id = _bl_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bon de livraison introuvable'; END IF;
  v_is_admin := public.has_role(v_user, 'super_admin'::public.app_role);
  v_logistique_deja_pris := public.colisage_logistique_deja_pris(_bl_id);
  SELECT EXISTS(SELECT 1 FROM public.colis WHERE bl_id = _bl_id) INTO v_has_colis;
  SELECT EXISTS(SELECT 1 FROM public.colis WHERE bl_id = _bl_id AND responsable_id = v_user) INTO v_owner;
  IF NOT v_is_admin THEN
    IF v_bl.statut NOT IN ('a_preparer', 'colisage_en_cours', 'annule', 'colisage_supprime') OR v_logistique_deja_pris THEN
      RAISE EXCEPTION 'Suppression interdite: le colisage est déjà pris en charge.' USING ERRCODE = 'check_violation';
    END IF;
    IF v_has_colis AND NOT v_owner THEN
      RAISE EXCEPTION 'Suppression interdite: vous n''êtes pas l''auteur de ce colisage.' USING ERRCODE = '42501';
    END IF;
  END IF;
  SELECT array_agg(colis_id), array_agg(DISTINCT (date_colisage::date))
    INTO v_colis_ids, v_dates FROM public.colis WHERE bl_id = _bl_id;
  v_nb_colis := COALESCE(array_length(v_colis_ids, 1), 0);
  IF v_bl.commande_id IS NOT NULL THEN
    DELETE FROM public.livsuivi_commandes WHERE commande_id = v_bl.commande_id;
    GET DIAGNOSTICS v_nb_livsuivi = ROW_COUNT;
  END IF;
  -- A3 FIX: document_id est uuid, pas text
  DELETE FROM public.notifications WHERE (document_id = _bl_id)
    OR (v_colis_ids IS NOT NULL AND document_id = ANY(v_colis_ids));
  GET DIAGNOSTICS v_nb_notifications = ROW_COUNT;
  DELETE FROM public.historique_envois WHERE (document_id = _bl_id)
    OR (v_colis_ids IS NOT NULL AND document_id = ANY(v_colis_ids));
  GET DIAGNOSTICS v_nb_envois = ROW_COUNT;
  UPDATE public.expeditions SET bl_id = NULL WHERE bl_id = _bl_id;
  GET DIAGNOSTICS v_nb_expeditions = ROW_COUNT;
  UPDATE public.livraisons SET bl_id = NULL WHERE bl_id = _bl_id;
  GET DIAGNOSTICS v_nb_livraisons = ROW_COUNT;
  UPDATE public.livraisons_commande SET bl_id = NULL WHERE bl_id = _bl_id;
  GET DIAGNOSTICS v_nb_livraisons_cmd = ROW_COUNT;
  DELETE FROM public.colis WHERE bl_id = _bl_id;
  UPDATE public.bons_livraison SET statut = 'colisage_supprime', annule_at = now(), annule_par = v_user,
    annule_par_nom = COALESCE((SELECT email FROM auth.users WHERE id = v_user), ''),
    annulation_motif = _motif, updated_at = now() WHERE bl_id = _bl_id;
  IF v_dates IS NOT NULL THEN
    FOREACH v_d IN ARRAY v_dates LOOP
      IF v_d IS NOT NULL THEN
        v_nb_tournees := v_nb_tournees + COALESCE(public.recalc_tournee_from_colis(v_d), 0);
      END IF;
    END LOOP;
  END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = v_user;
  v_summary := jsonb_build_object('bl_id', _bl_id, 'reference', v_bl.reference, 'motif', _motif,
    'colis_supprimes', v_nb_colis, 'notifications_supprimees', v_nb_notifications,
    'envois_supprimes', v_nb_envois, 'livsuivi_supprimes', v_nb_livsuivi,
    'livraisons_detachees', v_nb_livraisons, 'livraisons_commande_detachees', v_nb_livraisons_cmd,
    'expeditions_detachees', v_nb_expeditions, 'tournees_recalculees', v_nb_tournees,
    'role', CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END);
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (v_user, COALESCE(v_email, ''),
    CASE WHEN v_is_admin THEN 'colisage_supprime_super_admin' ELSE 'colisage_supprime' END,
    'bons_livraison', _bl_id::text, to_jsonb(v_bl), v_summary);
  RETURN v_summary;
END;
$function$;
