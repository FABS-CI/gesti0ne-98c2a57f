
CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL::text, _force boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ref text; v_client_id uuid;
  v_lignes int:=0; v_factures int:=0; v_bls int:=0; v_paiements int:=0;
  v_proformas int:=0; v_pro_lignes int:=0; v_retours int:=0; v_retour_lignes int:=0;
  v_colis int:=0; v_livraisons int:=0; v_expeditions int:=0;
  v_livsuivi int:=0; v_livraisons_commande int:=0;
  v_notifications int:=0; v_stock_mouvements int:=0;
  v_paiements_valides int; v_factures_ouvertes int; v_bls_avances int;
  v_bl_ids uuid[]; v_facture_ids uuid[];
  v_is_admin boolean;
BEGIN
  v_is_admin := public.has_role(auth.uid(),'super_admin');
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT reference, client_id INTO v_ref, v_client_id FROM public.commandes WHERE commande_id=_commande_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'Bon de commande introuvable' USING ERRCODE='P0002'; END IF;

  IF NOT _force THEN
    SELECT count(*) INTO v_paiements_valides FROM public.paiements p JOIN public.factures f ON f.facture_id=p.facture_id
      WHERE f.commande_id=_commande_id AND p.statut='valide';
    IF v_paiements_valides > 0 THEN
      RAISE EXCEPTION 'Suppression refusée : % paiement(s) validé(s) existent.', v_paiements_valides USING ERRCODE='P0001';
    END IF;
    SELECT count(*) INTO v_factures_ouvertes FROM public.factures WHERE commande_id=_commande_id AND statut<>'annulee';
    IF v_factures_ouvertes > 0 THEN
      RAISE EXCEPTION 'Suppression refusée : % facture(s) non annulée(s) rattachée(s).', v_factures_ouvertes USING ERRCODE='P0001';
    END IF;
    SELECT count(*) INTO v_bls_avances FROM public.bons_livraison WHERE commande_id=_commande_id AND statut IN ('expedie','livre');
    IF v_bls_avances > 0 THEN
      RAISE EXCEPTION 'Suppression refusée : % bon(s) de livraison expédié(s)/livré(s).', v_bls_avances USING ERRCODE='P0001';
    END IF;
  END IF;

  SELECT array_agg(bl_id) INTO v_bl_ids FROM public.bons_livraison WHERE commande_id=_commande_id;
  SELECT array_agg(facture_id) INTO v_facture_ids FROM public.factures WHERE commande_id=_commande_id;

  IF v_facture_ids IS NOT NULL THEN
    SELECT count(*) INTO v_paiements FROM public.paiements WHERE facture_id=ANY(v_facture_ids);
    DELETE FROM public.paiements WHERE facture_id=ANY(v_facture_ids);
  END IF;
  IF v_bl_ids IS NOT NULL THEN
    BEGIN
      SELECT count(*) INTO v_livraisons FROM public.livraisons WHERE bl_id=ANY(v_bl_ids);
      DELETE FROM public.livraisons WHERE bl_id=ANY(v_bl_ids);
    EXCEPTION WHEN undefined_column THEN NULL; END;
    BEGIN
      SELECT count(*) INTO v_expeditions FROM public.expeditions WHERE bl_id=ANY(v_bl_ids);
      DELETE FROM public.expeditions WHERE bl_id=ANY(v_bl_ids);
    EXCEPTION WHEN undefined_column OR undefined_table THEN NULL; END;
  END IF;
  SELECT count(*) INTO v_livraisons_commande FROM public.livraisons WHERE commande_id=_commande_id;
  DELETE FROM public.livraisons WHERE commande_id=_commande_id;
  SELECT count(*) INTO v_livsuivi FROM public.livsuivi_commandes WHERE commande_id=_commande_id;
  DELETE FROM public.livsuivi_commandes WHERE commande_id=_commande_id;
  SELECT count(*) INTO v_colis FROM public.colis WHERE commande_id=_commande_id;
  DELETE FROM public.colis WHERE commande_id=_commande_id;
  SELECT count(*) INTO v_retour_lignes FROM public.retour_lignes rl JOIN public.retours r ON r.retour_id=rl.retour_id WHERE r.commande_id=_commande_id;
  SELECT count(*) INTO v_retours FROM public.retours WHERE commande_id=_commande_id;
  DELETE FROM public.retours WHERE commande_id=_commande_id;
  SELECT count(*) INTO v_pro_lignes FROM public.proforma_lignes pl JOIN public.proformas p ON p.proforma_id=pl.proforma_id WHERE p.commande_id=_commande_id;
  SELECT count(*) INTO v_proformas FROM public.proformas WHERE commande_id=_commande_id;
  DELETE FROM public.proformas WHERE commande_id=_commande_id;
  BEGIN
    SELECT count(*) INTO v_notifications FROM public.notifications WHERE document_id=_commande_id::text;
    DELETE FROM public.notifications WHERE document_id=_commande_id::text;
  EXCEPTION WHEN undefined_column OR undefined_table THEN v_notifications:=0; END;
  SELECT count(*) INTO v_stock_mouvements FROM public.stock_mouvements WHERE document_id=_commande_id;
  DELETE FROM public.stock_mouvements WHERE document_id=_commande_id;
  SELECT count(*) INTO v_factures FROM public.factures WHERE commande_id=_commande_id;
  DELETE FROM public.factures WHERE commande_id=_commande_id;
  SELECT count(*) INTO v_bls FROM public.bons_livraison WHERE commande_id=_commande_id;
  DELETE FROM public.bons_livraison WHERE commande_id=_commande_id;
  SELECT count(*) INTO v_lignes FROM public.commande_lignes WHERE commande_id=_commande_id;
  DELETE FROM public.commandes WHERE commande_id=_commande_id;

  IF v_client_id IS NOT NULL THEN PERFORM public._recalc_solde_client_internal(v_client_id); END IF;

  RETURN jsonb_build_object('commande_id', _commande_id, 'reference', v_ref, 'motif', _motif, 'force', _force,
    'lignes_supprimees', v_lignes, 'proformas_supprimees', v_proformas,
    'proforma_lignes_supprimees', v_pro_lignes, 'factures_supprimees', v_factures,
    'bls_supprimes', v_bls, 'paiements_supprimes', v_paiements,
    'livraisons_supprimees', v_livraisons+v_livraisons_commande, 'expeditions_supprimees', v_expeditions,
    'livsuivi_supprimees', v_livsuivi, 'colis_supprimes', v_colis,
    'retours_supprimes', v_retours, 'retour_lignes_supprimees', v_retour_lignes,
    'notifications_supprimees', v_notifications, 'stock_mouvements_supprimes', v_stock_mouvements,
    'solde_client_recalcule', v_client_id IS NOT NULL);
END; $function$;

REVOKE ALL ON FUNCTION public.supprimer_commande_definitif(uuid, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.supprimer_commande_definitif(uuid, text, boolean) TO authenticated;

COMMENT ON FUNCTION public.supprimer_commande_definitif(uuid, text, boolean) IS
  'Suppression définitive d''une commande (super_admin). Avec _force=true, bypass des contrôles métier et suppression en cascade totale (factures, paiements, BL, etc.).';
