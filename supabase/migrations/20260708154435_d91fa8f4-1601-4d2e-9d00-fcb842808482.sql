
DROP FUNCTION IF EXISTS public.supprimer_commande_definitif(uuid, text);

CREATE OR REPLACE FUNCTION public.trg_stock_mouvements_no_delete()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
BEGIN
  IF current_setting('request.jwt.claims', true)::jsonb->>'role' = 'service_role' THEN
    RETURN OLD;
  END IF;
  IF current_setting('app.allow_stock_mouvement_delete', true) = 'on' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'Suppression interdite : un mouvement de stock validé ne peut pas être supprimé (mouvement_id=%)', OLD.mouvement_id
    USING ERRCODE = 'insufficient_privilege';
END;
$function$;

CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  _cmd public.commandes%ROWTYPE;
  _user uuid := auth.uid();
  _email text;
  _facture_ids uuid[];
  _bl_ids uuid[];
  _colis_ids uuid[];
  _retour_ids uuid[];
  _proforma_ids uuid[];
  _liv_ids uuid[];
  _livsuivi_ids uuid[];
  _paiement_ids uuid[];
  _tournee_ids uuid[];
  _summary jsonb := '{}'::jsonb;
  _c bigint;
BEGIN
  IF _user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_role(_user, 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'Suppression réservée au Super Administrateur' USING ERRCODE = '42501';
  END IF;

  PERFORM set_config('app.allow_paiement_delete', 'on', true);
  PERFORM set_config('app.allow_stock_mouvement_delete', 'on', true);

  SELECT * INTO _cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bon de commande introuvable' USING ERRCODE = 'P0002';
  END IF;

  SELECT email INTO _email FROM auth.users WHERE id = _user;

  SELECT array_agg(facture_id) INTO _facture_ids
    FROM public.factures WHERE commande_id = _commande_id;
  SELECT array_agg(bl_id) INTO _bl_ids
    FROM public.bons_livraison WHERE commande_id = _commande_id;
  SELECT array_agg(colis_id) INTO _colis_ids
    FROM public.colis
    WHERE commande_id = _commande_id
       OR (_bl_ids IS NOT NULL AND bl_id = ANY(_bl_ids));
  SELECT array_agg(retour_id) INTO _retour_ids
    FROM public.retours WHERE commande_id = _commande_id;
  SELECT array_agg(proforma_id) INTO _proforma_ids
    FROM public.proformas WHERE commande_id = _commande_id;
  SELECT array_agg(livraison_id) INTO _liv_ids
    FROM public.livraisons_commande WHERE commande_id = _commande_id;
  SELECT array_agg(id) INTO _livsuivi_ids
    FROM public.livsuivi_commandes WHERE commande_id = _commande_id;
  IF _facture_ids IS NOT NULL THEN
    SELECT array_agg(paiement_id) INTO _paiement_ids
      FROM public.paiements WHERE facture_id = ANY(_facture_ids);
  END IF;
  IF _colis_ids IS NOT NULL THEN
    SELECT array_agg(DISTINCT tournee_id) INTO _tournee_ids
      FROM public.colis
      WHERE colis_id = ANY(_colis_ids) AND tournee_id IS NOT NULL;
  END IF;

  -- Notifications
  DELETE FROM public.notifications
   WHERE (document_id = _commande_id)
      OR (_facture_ids IS NOT NULL AND document_id = ANY(_facture_ids))
      OR (_bl_ids IS NOT NULL AND document_id = ANY(_bl_ids))
      OR (_colis_ids IS NOT NULL AND document_id = ANY(_colis_ids))
      OR (_paiement_ids IS NOT NULL AND document_id = ANY(_paiement_ids))
      OR (_retour_ids IS NOT NULL AND document_id = ANY(_retour_ids));
  GET DIAGNOSTICS _c = ROW_COUNT;
  _summary := jsonb_set(_summary, '{notifications}', to_jsonb(_c));

  -- Historique d'envois (mails / FNE)
  DELETE FROM public.historique_envois
   WHERE document_id = _commande_id
      OR (_facture_ids IS NOT NULL AND document_id = ANY(_facture_ids))
      OR (_bl_ids IS NOT NULL AND document_id = ANY(_bl_ids));
  GET DIAGNOSTICS _c = ROW_COUNT;
  _summary := jsonb_set(_summary, '{historique_envois}', to_jsonb(_c));

  -- Mouvements de fidélité (paiements + factures)
  IF _paiement_ids IS NOT NULL THEN
    DELETE FROM public.client_fidelite_mouvements
     WHERE paiement_id = ANY(_paiement_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{fidelite_paiements}', to_jsonb(_c));
  END IF;
  IF _facture_ids IS NOT NULL THEN
    DELETE FROM public.client_fidelite_mouvements
     WHERE facture_id = ANY(_facture_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{fidelite_factures}', to_jsonb(_c));
  END IF;

  -- Écritures comptables (lignes cascade via FK)
  IF _facture_ids IS NOT NULL THEN
    DELETE FROM public.ecritures_comptables
     WHERE source_type = 'facture'
       AND source_id = ANY(_facture_ids);
    GET DIAGNOSTICS _c = ROW_COUNT;
    _summary := jsonb_set(_summary, '{ecritures_comptables}', to_jsonb(_c));
  END IF;

  -- Transactions
  DELETE FROM public.transactions WHERE commande_id = _commande_id;
  GET DIAGNOSTICS _c = ROW_COUNT;
  _summary := jsonb_set(_summary, '{transactions}', to_jsonb(_c));

  -- Mouvements de stock
  DELETE FROM public.stock_mouvements
   WHERE document_id = _commande_id
      OR (_facture_ids IS NOT NULL AND document_id = ANY(_facture_ids))
      OR (_bl_ids IS NOT NULL AND document_id = ANY(_bl_ids))
      OR (_colis_ids IS NOT NULL AND document_id = ANY(_colis_ids))
      OR (_retour_ids IS NOT NULL AND document_id = ANY(_retour_ids));
  GET DIAGNOSTICS _c = ROW_COUNT;
  _summary := jsonb_set(_summary, '{stock_mouvements}', to_jsonb(_c));

  -- === Bloc existant ===
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
  VALUES (
    _user, _email, 'delete_commande_definitif', 'commandes', _commande_id::text,
    to_jsonb(_cmd),
    jsonb_build_object(
      'motif', _motif,
      'role', 'super_admin',
      'reference', _cmd.reference,
      'client_id', _cmd.client_id,
      'client_nom', _cmd.client_nom,
      'deleted_at', now(),
      'cascade_summary', _summary
    )
  );

  RETURN _summary;
END;
$function$;
