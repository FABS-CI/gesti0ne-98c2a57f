
CREATE OR REPLACE FUNCTION public.supprimer_tournee(_tournee_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_t FROM public.tournees WHERE tournee_id = _tournee_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournée introuvable';
  END IF;

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

  -- Détachement des colis (déclenche trg_colis_sync_tournee_fn si présent)
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

  DELETE FROM public.notifications
   WHERE document_id = _tournee_id::text
     AND (document_type IS NULL OR document_type ILIKE '%tournee%' OR module ILIKE '%tournee%');
  GET DIAGNOSTICS v_nb_notifs = ROW_COUNT;

  -- Suppression de la tournée (cascade sur couts_logistiques_audit)
  DELETE FROM public.tournees WHERE tournee_id = _tournee_id;

  -- Recalcul des tournées restantes à cette date (colis détachés → autres tournées)
  IF v_t.date_tournee IS NOT NULL THEN
    v_nb_recalc := COALESCE(public.recalc_tournee_from_colis(v_t.date_tournee), 0);
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user;

  v_summary := jsonb_build_object(
    'tournee_id', _tournee_id,
    'reference', v_t.reference,
    'date_tournee', v_t.date_tournee,
    'motif', _motif,
    'colis_detaches', v_nb_colis,
    'livraisons_detachees', v_nb_livraisons,
    'livraisons_commande_detachees', v_nb_livraisons_cmd,
    'expeditions_detachees', v_nb_expeditions,
    'ecriture_lignes_detachees', v_nb_ecr_lignes,
    'couts_audit_supprimes', v_nb_couts,
    'notifications_supprimees', v_nb_notifs,
    'tournees_recalculees', v_nb_recalc,
    'role', CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END
  );

  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (
    v_user,
    COALESCE(v_email, ''),
    CASE WHEN v_is_admin THEN 'tournee_supprimee_super_admin' ELSE 'tournee_supprimee' END,
    'tournees',
    _tournee_id::text,
    to_jsonb(v_t),
    v_summary
  );

  RETURN v_summary;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.supprimer_tournee(uuid, text) TO authenticated;
