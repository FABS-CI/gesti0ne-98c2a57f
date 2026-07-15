CREATE OR REPLACE FUNCTION public.supprimer_colisage(_bl_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
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
  v_colis_ids_text text[];
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
BEGIN PERFORM public.assert_permission('colisage.supprimer');
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
  SELECT array_agg(colis_id), array_agg(colis_id::text), array_agg(DISTINCT (date_colisage::date))
    INTO v_colis_ids, v_colis_ids_text, v_dates FROM public.colis WHERE bl_id = _bl_id;
  v_nb_colis := COALESCE(array_length(v_colis_ids, 1), 0);
  IF v_bl.commande_id IS NOT NULL THEN
    DELETE FROM public.livsuivi_commandes WHERE commande_id = v_bl.commande_id;
    GET DIAGNOSTICS v_nb_livsuivi = ROW_COUNT;
  END IF;
  DELETE FROM public.notifications WHERE (document_id = _bl_id::text)
    OR (v_colis_ids_text IS NOT NULL AND document_id = ANY(v_colis_ids_text));
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

CREATE OR REPLACE FUNCTION public.supprimer_livraison_suivi(_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_email text;
  v_is_admin boolean;
  v_row public.livsuivi_commandes;
  v_nb_hist int := 0;
  v_nb_colis int := 0;
  v_nb_livraisons int := 0;
  v_nb_livraisons_cmd int := 0;
  v_nb_notifs int := 0;
  v_summary jsonb;
BEGIN PERFORM public.assert_permission('livraison_suivi.supprimer');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000'; END IF;
  SELECT * INTO v_row FROM public.livsuivi_commandes WHERE id = _id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Suivi de livraison introuvable'; END IF;
  v_is_admin := public.has_role(v_user, 'super_admin'::public.app_role);
  IF NOT v_is_admin AND COALESCE(v_row.cloturee, false) THEN
    RAISE EXCEPTION 'Suppression interdite : ce suivi est clôturé — seul un super_admin peut le supprimer.'
      USING ERRCODE = 'check_violation';
  END IF;
  SELECT count(*) INTO v_nb_hist FROM public.livsuivi_historique WHERE livraison_id = _id;
  IF v_row.bl_id IS NOT NULL THEN
    UPDATE public.colis SET statut_logistique = 'pret',
      date_remise_livreur = NULL, date_depart = NULL, date_arrivee_estimee = NULL,
      date_arrivee_client = NULL, date_livraison_reelle = NULL, date_depot_gare = NULL,
      date_arrivee_ville = NULL, date_remise_client = NULL, updated_at = now()
    WHERE bl_id = v_row.bl_id;
    GET DIAGNOSTICS v_nb_colis = ROW_COUNT;
    UPDATE public.livraisons SET bl_id = NULL WHERE bl_id = v_row.bl_id;
    GET DIAGNOSTICS v_nb_livraisons = ROW_COUNT;
    UPDATE public.livraisons_commande SET bl_id = NULL WHERE bl_id = v_row.bl_id;
    GET DIAGNOSTICS v_nb_livraisons_cmd = ROW_COUNT;
  END IF;
  DELETE FROM public.notifications WHERE document_id = _id::text
    AND (document_type IS NULL OR document_type ILIKE '%livraison%' OR module ILIKE '%livraison%');
  GET DIAGNOSTICS v_nb_notifs = ROW_COUNT;
  DELETE FROM public.livsuivi_commandes WHERE id = _id;
  SELECT email INTO v_email FROM auth.users WHERE id = v_user;
  v_summary := jsonb_build_object('livraison_id', _id, 'commande_id', v_row.commande_id, 'bl_id', v_row.bl_id,
    'motif', _motif, 'historique_supprime', v_nb_hist, 'colis_reinitialises', v_nb_colis,
    'livraisons_detachees', v_nb_livraisons, 'livraisons_commande_detachees', v_nb_livraisons_cmd,
    'notifications_supprimees', v_nb_notifs,
    'role', CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END);
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (v_user, COALESCE(v_email, ''),
    CASE WHEN v_is_admin THEN 'livsuivi_supprime_super_admin' ELSE 'livsuivi_supprime' END,
    'livsuivi_commandes', _id::text, to_jsonb(v_row), v_summary);
  RETURN v_summary;
END;
$function$;

CREATE OR REPLACE FUNCTION public.supprimer_tournee(_tournee_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_email text;
  v_is_admin boolean;
  v_t public.tournees;
  v_nb_colis int := 0;
  v_nb_livraisons int := 0;
  v_nb_livraisons_cmd int := 0;
  v_nb_expeditions int := 0;
  v_nb_ecr_lignes int := 0;
  v_nb_notifs int := 0;
  v_nb_couts int := 0;
  v_nb_recalc int := 0;
  v_summary jsonb;
BEGIN PERFORM public.assert_permission('tournees.supprimer');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000'; END IF;
  SELECT * INTO v_t FROM public.tournees WHERE tournee_id = _tournee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tournée introuvable'; END IF;
  v_is_admin := public.has_role(v_user, 'super_admin'::public.app_role);
  IF NOT v_is_admin THEN
    IF v_t.statut NOT IN ('preparee','en_cours') THEN
      RAISE EXCEPTION 'Suppression interdite : la tournée est % — seul un super_admin peut la supprimer.', v_t.statut
        USING ERRCODE = 'check_violation';
    END IF;
    IF v_t.validation_statut = 'validee' OR v_t.ecriture_id IS NOT NULL THEN
      RAISE EXCEPTION 'Suppression interdite : la tournée a une écriture comptable validée.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  UPDATE public.colis SET tournee_id = NULL WHERE tournee_id = _tournee_id;
  GET DIAGNOSTICS v_nb_colis = ROW_COUNT;
  UPDATE public.livraisons SET tournee_id = NULL WHERE tournee_id = _tournee_id;
  GET DIAGNOSTICS v_nb_livraisons = ROW_COUNT;
  UPDATE public.livraisons_commande SET tournee_id = NULL WHERE tournee_id = _tournee_id;
  GET DIAGNOSTICS v_nb_livraisons_cmd = ROW_COUNT;
  UPDATE public.expeditions SET tournee_id = NULL WHERE tournee_id = _tournee_id;
  GET DIAGNOSTICS v_nb_expeditions = ROW_COUNT;
  UPDATE public.ecriture_lignes SET tournee_id = NULL WHERE tournee_id = _tournee_id;
  GET DIAGNOSTICS v_nb_ecr_lignes = ROW_COUNT;
  SELECT count(*) INTO v_nb_couts FROM public.couts_logistiques_audit WHERE tournee_id = _tournee_id;
  DELETE FROM public.notifications WHERE document_id = _tournee_id::text
    AND (document_type IS NULL OR document_type ILIKE '%tournee%' OR module ILIKE '%tournee%');
  GET DIAGNOSTICS v_nb_notifs = ROW_COUNT;
  DELETE FROM public.tournees WHERE tournee_id = _tournee_id;
  IF v_t.date_tournee IS NOT NULL THEN
    v_nb_recalc := COALESCE(public.recalc_tournee_from_colis(v_t.date_tournee), 0);
  END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = v_user;
  v_summary := jsonb_build_object('tournee_id', _tournee_id, 'reference', v_t.reference,
    'date_tournee', v_t.date_tournee, 'motif', _motif, 'colis_detaches', v_nb_colis,
    'livraisons_detachees', v_nb_livraisons, 'livraisons_commande_detachees', v_nb_livraisons_cmd,
    'expeditions_detachees', v_nb_expeditions, 'ecriture_lignes_detachees', v_nb_ecr_lignes,
    'couts_audit_supprimes', v_nb_couts, 'notifications_supprimees', v_nb_notifs,
    'tournees_recalculees', v_nb_recalc,
    'role', CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END);
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (v_user, COALESCE(v_email, ''),
    CASE WHEN v_is_admin THEN 'tournee_supprimee_super_admin' ELSE 'tournee_supprimee' END,
    'tournees', _tournee_id::text, to_jsonb(v_t), v_summary);
  RETURN v_summary;
END;
$function$;

CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  _cmd public.commandes%ROWTYPE;
  _user uuid := auth.uid();
  _email text;
  _facture_ids uuid[]; _bl_ids uuid[]; _colis_ids uuid[]; _retour_ids uuid[];
  _proforma_ids uuid[]; _liv_ids uuid[]; _livsuivi_ids uuid[];
  _paiement_ids uuid[]; _tournee_ids uuid[];
  _summary jsonb := '{}'::jsonb;
  _c bigint;
BEGIN PERFORM public.assert_permission('commandes.supprimer');
  IF _user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000'; END IF;
  IF NOT public.has_role(_user, 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'Suppression réservée au Super Administrateur' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('app.allow_paiement_delete', 'on', true);
  PERFORM set_config('app.allow_stock_mouvement_delete', 'on', true);
  SELECT * INTO _cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bon de commande introuvable' USING ERRCODE = 'P0002'; END IF;
  SELECT email INTO _email FROM auth.users WHERE id = _user;
  SELECT array_agg(facture_id) INTO _facture_ids FROM public.factures WHERE commande_id = _commande_id;
  SELECT array_agg(bl_id) INTO _bl_ids FROM public.bons_livraison WHERE commande_id = _commande_id;
  SELECT array_agg(colis_id) INTO _colis_ids FROM public.colis
    WHERE commande_id = _commande_id OR (_bl_ids IS NOT NULL AND bl_id = ANY(_bl_ids));
  SELECT array_agg(retour_id) INTO _retour_ids FROM public.retours WHERE commande_id = _commande_id;
  SELECT array_agg(proforma_id) INTO _proforma_ids FROM public.proformas WHERE commande_id = _commande_id;
  SELECT array_agg(livraison_id) INTO _liv_ids FROM public.livraisons_commande WHERE commande_id = _commande_id;
  SELECT array_agg(id) INTO _livsuivi_ids FROM public.livsuivi_commandes WHERE commande_id = _commande_id;
  IF _facture_ids IS NOT NULL THEN
    SELECT array_agg(paiement_id) INTO _paiement_ids FROM public.paiements WHERE facture_id = ANY(_facture_ids);
  END IF;
  IF _colis_ids IS NOT NULL THEN
    SELECT array_agg(DISTINCT tournee_id) INTO _tournee_ids FROM public.colis
      WHERE colis_id = ANY(_colis_ids) AND tournee_id IS NOT NULL;
  END IF;
  DELETE FROM public.notifications WHERE (document_id = _commande_id)
    OR (_facture_ids IS NOT NULL AND document_id = ANY(_facture_ids))
    OR (_bl_ids IS NOT NULL AND document_id = ANY(_bl_ids))
    OR (_colis_ids IS NOT NULL AND document_id = ANY(_colis_ids))
    OR (_paiement_ids IS NOT NULL AND document_id = ANY(_paiement_ids))
    OR (_retour_ids IS NOT NULL AND document_id = ANY(_retour_ids));
  GET DIAGNOSTICS _c = ROW_COUNT;
  _summary := jsonb_set(_summary, '{notifications}', to_jsonb(_c));
  DELETE FROM public.historique_envois WHERE document_id = _commande_id
    OR (_facture_ids IS NOT NULL AND document_id = ANY(_facture_ids))
    OR (_bl_ids IS NOT NULL AND document_id = ANY(_bl_ids));
  GET DIAGNOSTICS _c = ROW_COUNT;
  _summary := jsonb_set(_summary, '{historique_envois}', to_jsonb(_c));
  IF _paiement_ids IS NOT NULL THEN
    DELETE FROM public.client_fidelite_mouvements WHERE paiement_id = ANY(_paiement_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{fidelite_paiements}', to_jsonb(_c));
  END IF;
  IF _facture_ids IS NOT NULL THEN
    DELETE FROM public.client_fidelite_mouvements WHERE facture_id = ANY(_facture_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{fidelite_factures}', to_jsonb(_c));
  END IF;
  IF _facture_ids IS NOT NULL THEN
    DELETE FROM public.ecritures_comptables WHERE source_type = 'facture' AND source_id = ANY(_facture_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{ecritures_comptables}', to_jsonb(_c));
  END IF;
  DELETE FROM public.transactions WHERE commande_id = _commande_id;
  GET DIAGNOSTICS _c = ROW_COUNT;
  _summary := jsonb_set(_summary, '{transactions}', to_jsonb(_c));
  DELETE FROM public.stock_mouvements WHERE document_id = _commande_id
    OR (_facture_ids IS NOT NULL AND document_id = ANY(_facture_ids))
    OR (_bl_ids IS NOT NULL AND document_id = ANY(_bl_ids))
    OR (_colis_ids IS NOT NULL AND document_id = ANY(_colis_ids))
    OR (_retour_ids IS NOT NULL AND document_id = ANY(_retour_ids));
  GET DIAGNOSTICS _c = ROW_COUNT;
  _summary := jsonb_set(_summary, '{stock_mouvements}', to_jsonb(_c));
  IF _facture_ids IS NOT NULL THEN
    DELETE FROM public.paiements WHERE facture_id = ANY(_facture_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{paiements}', to_jsonb(_c));
    DELETE FROM public.fne_factures WHERE facture_id = ANY(_facture_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{fne_factures}', to_jsonb(_c));
    DELETE FROM public.bons_retour WHERE facture_id = ANY(_facture_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{bons_retour}', to_jsonb(_c));
    UPDATE public.retours SET facture_id = NULL WHERE facture_id = ANY(_facture_ids);
    DELETE FROM public.factures WHERE facture_id = ANY(_facture_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{factures}', to_jsonb(_c));
  END IF;
  IF _bl_ids IS NOT NULL THEN
    DELETE FROM public.expeditions WHERE bl_id = ANY(_bl_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{expeditions}', to_jsonb(_c));
    UPDATE public.livraisons_commande SET bl_id = NULL WHERE bl_id = ANY(_bl_ids);
    DELETE FROM public.bons_livraison WHERE bl_id = ANY(_bl_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{bons_livraison}', to_jsonb(_c));
  END IF;
  IF _colis_ids IS NOT NULL THEN
    DELETE FROM public.colis_lignes WHERE colis_id = ANY(_colis_ids);
    DELETE FROM public.colis_statut_historique WHERE colis_id = ANY(_colis_ids);
    DELETE FROM public.colis WHERE colis_id = ANY(_colis_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{colis}', to_jsonb(_c));
  END IF;
  IF _retour_ids IS NOT NULL THEN
    DELETE FROM public.retour_lignes WHERE retour_id = ANY(_retour_ids);
    DELETE FROM public.retours WHERE retour_id = ANY(_retour_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{retours}', to_jsonb(_c));
  END IF;
  IF _proforma_ids IS NOT NULL THEN
    DELETE FROM public.proforma_lignes WHERE proforma_id = ANY(_proforma_ids);
    DELETE FROM public.proformas WHERE proforma_id = ANY(_proforma_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{proformas}', to_jsonb(_c));
  END IF;
  IF _livsuivi_ids IS NOT NULL THEN
    DELETE FROM public.livsuivi_commandes WHERE id = ANY(_livsuivi_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{livsuivi_commandes}', to_jsonb(_c));
  END IF;
  IF _liv_ids IS NOT NULL THEN
    DELETE FROM public.livraison_commande_historique WHERE livraison_commande_id = ANY(_liv_ids);
    DELETE FROM public.livraisons_commande WHERE livraison_id = ANY(_liv_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{livraisons_commande}', to_jsonb(_c));
  END IF;
  DELETE FROM public.commande_lignes WHERE commande_id = _commande_id;
  DELETE FROM public.commandes WHERE commande_id = _commande_id;
  _summary := jsonb_set(_summary, '{commandes}', to_jsonb(1));
  IF _tournee_ids IS NOT NULL THEN
    _summary := jsonb_set(_summary, '{tournees_impactees}', to_jsonb(array_length(_tournee_ids, 1)));
  END IF;
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (_user, _email, 'delete_commande_definitif', 'commandes', _commande_id::text, to_jsonb(_cmd),
    jsonb_build_object('motif', _motif, 'role', 'super_admin', 'reference', _cmd.reference,
      'client_id', _cmd.client_id, 'client_nom', _cmd.client_nom, 'deleted_at', now(),
      'cascade_summary', _summary));
  RETURN _summary;
END;
$function$;