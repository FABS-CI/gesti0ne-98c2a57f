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
BEGIN PERFORM public.assert_permission('colisage.annuler');
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

  SELECT email INTO v_email FROM auth.users WHERE id = v_user;

  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (
    v_user, COALESCE(v_email, ''), 'colisage_annule', 'bons_livraison', _bl_id::text,
    to_jsonb(v_bl),
    jsonb_build_object('motif', _motif, 'reference', v_bl.reference,
      'role', CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.annuler_incident(_incident_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ BEGIN PERFORM public.assert_permission('incidents.annuler'); UPDATE public.incidents SET statut='annule',updated_at=now() WHERE incident_id=_incident_id; END $function$;

CREATE OR REPLACE FUNCTION public.annuler_inventaire(_inventaire_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ BEGIN PERFORM public.assert_permission('inventaires.annuler'); UPDATE public.inventaires SET statut='annule',updated_at=now() WHERE inventaire_id=_inventaire_id; END $function$;

CREATE OR REPLACE FUNCTION public.annuler_paiement(_paiement_id uuid, _raison text, _notes text DEFAULT NULL::text)
 RETURNS paiements
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_p public.paiements;
  v_fac record;
  v_total_paye numeric;
  v_nouveau_statut text;
BEGIN PERFORM public.assert_permission('paiements.annuler');
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée pour annuler un paiement';
  END IF;
  IF _raison IS NULL OR btrim(_raison) = '' THEN
    RAISE EXCEPTION 'Raison d''annulation obligatoire';
  END IF;

  SELECT * INTO v_p FROM public.paiements WHERE paiement_id = _paiement_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Paiement introuvable'; END IF;
  IF v_p.statut = 'annule' THEN RAISE EXCEPTION 'Paiement déjà annulé'; END IF;

  UPDATE public.paiements
     SET statut = 'annule',
         updated_at = now(),
         notes = COALESCE(notes,'') || E'\n[Annulé le ' || to_char(now(),'YYYY-MM-DD HH24:MI') || '] ' || _raison
   WHERE paiement_id = _paiement_id
   RETURNING * INTO v_p;

  IF v_p.facture_id IS NOT NULL THEN
    SELECT * INTO v_fac FROM public.factures WHERE facture_id = v_p.facture_id FOR UPDATE;
    IF FOUND THEN
      v_total_paye := GREATEST(0, COALESCE(v_fac.montant_paye, 0) - COALESCE(v_p.montant, 0));
      IF v_total_paye >= COALESCE(v_fac.montant_total, 0) AND COALESCE(v_fac.montant_total,0) > 0 THEN
        v_nouveau_statut := 'payee';
      ELSIF v_total_paye > 0 THEN
        v_nouveau_statut := 'partielle';
      ELSE
        v_nouveau_statut := 'impayee';
      END IF;
      UPDATE public.factures
         SET montant_paye = v_total_paye,
             statut = v_nouveau_statut,
             updated_at = now()
       WHERE facture_id = v_fac.facture_id;
    END IF;
  END IF;

  INSERT INTO public.paiement_annulations_audit
    (paiement_id, facture_id, annule_par, raison, notes, montant_annule)
  VALUES
    (v_p.paiement_id, v_p.facture_id, auth.uid(), _raison, _notes, COALESCE(v_p.montant, 0));

  RETURN v_p;
END $function$;

CREATE OR REPLACE FUNCTION public.annuler_retour(_retour_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  r public.retours;
  l record;
  v_actuel int;
BEGIN PERFORM public.assert_permission('retours.annuler');
  SELECT * INTO r FROM public.retours WHERE retour_id = _retour_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Retour introuvable';
  END IF;
  IF r.statut = 'annule' THEN
    RETURN;
  END IF;

  IF r.depot_id IS NOT NULL THEN
    FOR l IN
      SELECT produit_id, quantite, motif
      FROM public.retour_lignes
      WHERE retour_id = _retour_id
        AND produit_id IS NOT NULL
        AND remise_en_stock = true
    LOOP
      SELECT quantite INTO v_actuel
      FROM public.stocks_depots
      WHERE produit_id = l.produit_id AND depot_id = r.depot_id
      FOR UPDATE;

      IF v_actuel IS NOT NULL AND v_actuel >= l.quantite THEN
        PERFORM public.ajuster_stock_depot(
          l.produit_id, r.depot_id, v_actuel - l.quantite,
          'Annulation retour ' || COALESCE(r.numero, r.reference),
          'annulation_retour', r.retour_id, COALESCE(r.numero, r.reference),
          'retours', l.motif
        );
      END IF;
    END LOOP;
  END IF;

  UPDATE public.retours
     SET statut = 'annule', updated_at = now()
   WHERE retour_id = _retour_id;

  INSERT INTO public.notifications(titre, message, type_notification, module,
    document_type, document_id, document_reference, lien, priorite, role_cible)
  VALUES(
    'Retour annulé',
    'Le retour ' || COALESCE(r.numero, r.reference) || ' a été annulé.',
    'warning', 'retours', 'retour', r.retour_id,
    COALESCE(r.numero, r.reference), '/retours/' || r.retour_id::text,
    'normale', 'gestionnaire_stock'
  );
END
$function$;

CREATE OR REPLACE FUNCTION public.annuler_specimen(_specimen_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ BEGIN PERFORM public.assert_permission('specimens.annuler'); UPDATE public.specimens SET statut='annule',updated_at=now() WHERE specimen_id=_specimen_id; END $function$;

CREATE OR REPLACE FUNCTION public.annuler_transfert(_transfert_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ BEGIN PERFORM public.assert_permission('transferts.annuler'); UPDATE public.transferts SET statut='annule',updated_at=now() WHERE transfert_id=_transfert_id; END $function$;

CREATE OR REPLACE FUNCTION public.annuler_validation_tournee(_tournee_id uuid, _commentaire text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_ecr uuid; v_email text;
BEGIN PERFORM public.assert_permission('tournees.annuler');
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé : annulation réservée à la direction.';
  END IF;
  SELECT ecriture_id INTO v_ecr FROM public.tournees WHERE tournee_id=_tournee_id FOR UPDATE;
  IF v_ecr IS NOT NULL THEN
    DELETE FROM public.ecriture_lignes WHERE ecriture_id = v_ecr;
    DELETE FROM public.ecritures_comptables WHERE ecriture_id = v_ecr;
  END IF;
  UPDATE public.tournees
    SET validation_statut='annule',
        validation_at=now(),
        validation_by=auth.uid(),
        validation_commentaire=_commentaire,
        ecriture_id=NULL,
        mode_reglement=NULL
    WHERE tournee_id=_tournee_id;
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.couts_logistiques_audit(tournee_id, action, actor, actor_email, commentaire)
  VALUES (_tournee_id, 'annulation', auth.uid(), v_email, _commentaire);
END $function$;