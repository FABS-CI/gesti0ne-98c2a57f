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
  -- Réinitialise le BL au statut « à préparer » pour permettre un nouveau colisage,
  -- tout en conservant la trace de l'annulation (motif + auteur + horodatage).
  UPDATE public.bons_livraison
     SET statut = 'a_preparer',
         annule_at = now(),
         annule_par = v_user,
         annule_par_nom = COALESCE((SELECT email FROM auth.users WHERE id = v_user), ''),
         annulation_motif = _motif,
         updated_at = now()
   WHERE bl_id = _bl_id;
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