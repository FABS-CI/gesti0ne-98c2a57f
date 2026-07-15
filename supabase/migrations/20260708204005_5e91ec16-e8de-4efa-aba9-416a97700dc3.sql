
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

  -- Capturer les dates des colis avant suppression, pour recalculer les tournées
  SELECT array_agg(DISTINCT date_colisage::date)
    INTO v_dates
  FROM public.colis WHERE bl_id = _bl_id;

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

  -- Recalcul des tournées impactées (cohérence avec supprimer_colisage)
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
      'tournees_recalculees', COALESCE(array_length(v_dates,1),0))
  );
END;
$function$;
