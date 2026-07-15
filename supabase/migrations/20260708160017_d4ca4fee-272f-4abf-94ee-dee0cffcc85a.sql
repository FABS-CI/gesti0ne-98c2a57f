
CREATE OR REPLACE FUNCTION public.supprimer_livraison_suivi(_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_row FROM public.livsuivi_commandes WHERE id = _id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Suivi de livraison introuvable';
  END IF;

  v_is_admin := public.has_role(v_user, 'super_admin'::public.app_role);

  IF NOT v_is_admin AND COALESCE(v_row.cloturee, false) THEN
    RAISE EXCEPTION 'Suppression interdite : ce suivi est clôturé — seul un super_admin peut le supprimer.'
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT count(*) INTO v_nb_hist FROM public.livsuivi_historique WHERE livraison_id = _id;

  -- Rollback des colis liés au BL (retour à l'état « prêt »)
  IF v_row.bl_id IS NOT NULL THEN
    UPDATE public.colis
       SET statut_logistique = 'pret',
           date_remise_livreur = NULL,
           date_depart = NULL,
           date_arrivee_estimee = NULL,
           date_arrivee_client = NULL,
           date_livraison_reelle = NULL,
           date_depot_gare = NULL,
           date_arrivee_ville = NULL,
           date_remise_client = NULL,
           updated_at = now()
     WHERE bl_id = v_row.bl_id;
    GET DIAGNOSTICS v_nb_colis = ROW_COUNT;

    UPDATE public.livraisons SET bl_id = NULL WHERE bl_id = v_row.bl_id;
    GET DIAGNOSTICS v_nb_livraisons = ROW_COUNT;

    UPDATE public.livraisons_commande SET bl_id = NULL WHERE bl_id = v_row.bl_id;
    GET DIAGNOSTICS v_nb_livraisons_cmd = ROW_COUNT;
  END IF;

  DELETE FROM public.notifications
   WHERE document_id = _id::text
     AND (document_type IS NULL OR document_type ILIKE '%livraison%' OR module ILIKE '%livraison%');
  GET DIAGNOSTICS v_nb_notifs = ROW_COUNT;

  -- Suppression du suivi (cascade sur livsuivi_historique)
  DELETE FROM public.livsuivi_commandes WHERE id = _id;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user;

  v_summary := jsonb_build_object(
    'livraison_id', _id,
    'commande_id', v_row.commande_id,
    'bl_id', v_row.bl_id,
    'motif', _motif,
    'historique_supprime', v_nb_hist,
    'colis_reinitialises', v_nb_colis,
    'livraisons_detachees', v_nb_livraisons,
    'livraisons_commande_detachees', v_nb_livraisons_cmd,
    'notifications_supprimees', v_nb_notifs,
    'role', CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END
  );

  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (
    v_user,
    COALESCE(v_email, ''),
    CASE WHEN v_is_admin THEN 'livsuivi_supprime_super_admin' ELSE 'livsuivi_supprime' END,
    'livsuivi_commandes',
    _id::text,
    to_jsonb(v_row),
    v_summary
  );

  RETURN v_summary;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.supprimer_livraison_suivi(uuid, text) TO authenticated;
