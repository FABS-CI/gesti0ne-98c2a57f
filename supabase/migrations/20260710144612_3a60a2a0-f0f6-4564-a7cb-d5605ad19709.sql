CREATE OR REPLACE FUNCTION public.supprimer_achat(_achat_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_email text;
  v_is_admin boolean;
  v_a public.achats;
  v_ex_cloture boolean := false;
  v_nb_lignes int := 0;
  v_nb_stock int := 0;
  v_nb_ecr int := 0;
  v_nb_notifs int := 0;
  v_summary jsonb;
BEGIN PERFORM public.assert_permission('achats.supprimer');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000'; END IF;
  SELECT * INTO v_a FROM public.achats WHERE achat_id = _achat_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Approvisionnement introuvable'; END IF;
  v_is_admin := public.has_role(v_user, 'super_admin'::public.app_role);
  IF v_a.exercice_id IS NOT NULL THEN
    SELECT (statut = 'cloture') INTO v_ex_cloture FROM public.exercices WHERE exercice_id = v_a.exercice_id;
    v_ex_cloture := COALESCE(v_ex_cloture, false);
  END IF;
  IF NOT v_is_admin THEN
    IF v_a.statut IN ('recu','paye') THEN
      RAISE EXCEPTION 'Suppression interdite : l''approvisionnement est % — seul un super_admin peut le supprimer.', v_a.statut
        USING ERRCODE = 'check_violation';
    END IF;
    IF v_ex_cloture THEN
      RAISE EXCEPTION 'Suppression interdite : exercice comptable clôturé.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  SELECT count(*) INTO v_nb_lignes FROM public.achat_lignes WHERE achat_id = _achat_id;
  SET LOCAL app.allow_stock_mouvement_delete = 'on';
  DELETE FROM public.stock_mouvements WHERE document_id = _achat_id AND document_table = 'achats';
  GET DIAGNOSTICS v_nb_stock = ROW_COUNT;
  RESET app.allow_stock_mouvement_delete;
  DELETE FROM public.ecritures_comptables WHERE source_type = 'achat' AND source_id = _achat_id;
  GET DIAGNOSTICS v_nb_ecr = ROW_COUNT;
  DELETE FROM public.notifications WHERE document_id = _achat_id
    AND (document_type IS NULL OR document_type ILIKE '%achat%' OR module ILIKE '%achat%');
  GET DIAGNOSTICS v_nb_notifs = ROW_COUNT;
  DELETE FROM public.achats WHERE achat_id = _achat_id;
  SELECT email INTO v_email FROM auth.users WHERE id = v_user;
  v_summary := jsonb_build_object('achat_id', _achat_id, 'reference', v_a.reference, 'motif', _motif,
    'lignes_supprimees', v_nb_lignes, 'stock_mouvements_supprimes', v_nb_stock,
    'ecritures_supprimees', v_nb_ecr, 'notifications_supprimees', v_nb_notifs,
    'role', CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END);
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (v_user, COALESCE(v_email,''), CASE WHEN v_is_admin THEN 'achat_supprime_super_admin' ELSE 'achat_supprime' END,
    'achats', _achat_id::text, to_jsonb(v_a), v_summary);
  RETURN v_summary;
END;
$function$;