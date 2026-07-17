
-- LOT 1 : RLS write denied
DROP POLICY IF EXISTS "commandes write auth" ON public.commandes;
CREATE POLICY "commandes_write_denied" ON public.commandes FOR ALL TO authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS "commande_lignes write auth" ON public.commande_lignes;
CREATE POLICY "commande_lignes_write_denied" ON public.commande_lignes FOR ALL TO authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS auth_write_bons_livraison ON public.bons_livraison;
CREATE POLICY bons_livraison_write_denied ON public.bons_livraison FOR ALL TO authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS auth_write_colis ON public.colis;
CREATE POLICY colis_write_denied ON public.colis FOR ALL TO authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS auth_write_colis_lignes ON public.colis_lignes;
CREATE POLICY colis_lignes_write_denied ON public.colis_lignes FOR ALL TO authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS auth_write_colis_hist ON public.colis_statut_historique;
CREATE POLICY colis_hist_write_denied ON public.colis_statut_historique FOR ALL TO authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS factures_write ON public.factures;
CREATE POLICY factures_write_denied ON public.factures FOR ALL TO authenticated USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS paiements_write ON public.paiements;
CREATE POLICY paiements_write_denied ON public.paiements FOR ALL TO authenticated USING (false) WITH CHECK (false);

-- LOT 2 : annuler_commande + supprimer_facture_definitif
CREATE OR REPLACE FUNCTION public.annuler_commande(_commande_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_cmd public.commandes; v_depot uuid; r record; v_new_stock numeric;
  v_has_paiement_valide boolean; v_bls_avances int;
BEGIN
  PERFORM public.assert_permission('commandes.annuler');
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_cmd.statut = 'annulee' THEN RAISE EXCEPTION 'Commande déjà annulée'; END IF;

  SELECT EXISTS(SELECT 1 FROM public.paiements p JOIN public.factures f ON f.facture_id=p.facture_id
    WHERE f.commande_id=_commande_id AND p.statut='valide') INTO v_has_paiement_valide;
  IF v_has_paiement_valide THEN
    RAISE EXCEPTION 'Impossible d''annuler : des paiements validés existent. Annuler d''abord les paiements.' USING ERRCODE='P0001';
  END IF;

  SELECT count(*) INTO v_bls_avances FROM public.bons_livraison
    WHERE commande_id=_commande_id AND statut IN ('expedie','livre');
  IF v_bls_avances > 0 THEN
    RAISE EXCEPTION 'Annulation refusée : % bon(s) de livraison expédié(s)/livré(s). La marchandise est partie, générer un retour au lieu d''annuler.', v_bls_avances USING ERRCODE='P0001';
  END IF;

  IF v_cmd.statut = 'validee' THEN
    v_depot := v_cmd.depot_id;
    IF v_depot IS NULL THEN SELECT depot_id INTO v_depot FROM public.depots WHERE is_principal=true LIMIT 1; END IF;
    IF v_depot IS NOT NULL THEN
      FOR r IN SELECT cl.produit_id, cl.quantite FROM public.commande_lignes cl
               WHERE cl.commande_id=_commande_id AND cl.produit_id IS NOT NULL LOOP
        INSERT INTO public.stocks_depots(produit_id, depot_id, quantite) VALUES (r.produit_id, v_depot, r.quantite)
          ON CONFLICT (produit_id, depot_id) DO UPDATE SET quantite=public.stocks_depots.quantite+EXCLUDED.quantite, updated_at=now();
        SELECT quantite INTO v_new_stock FROM public.stocks_depots WHERE produit_id=r.produit_id AND depot_id=v_depot;
        INSERT INTO public.stock_mouvements(produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie, stock_resultant, origine, document_id, document_reference, document_table, user_id, motif)
        VALUES (r.produit_id, v_depot, 'entree', r.quantite, r.quantite, 0, v_new_stock, 'annulation_commande', _commande_id, v_cmd.reference, 'commandes', auth.uid(), COALESCE(_motif,'Annulation commande'));
      END LOOP;
    END IF;
    UPDATE public.factures SET statut='annulee' WHERE commande_id=_commande_id;
    UPDATE public.bons_livraison SET statut='annulee' WHERE commande_id=_commande_id;
  END IF;

  DELETE FROM public.colis
    WHERE bl_id IN (SELECT bl_id FROM public.bons_livraison WHERE commande_id=_commande_id)
       OR commande_id=_commande_id;

  UPDATE public.proformas SET statut='annulee', updated_at=now()
    WHERE commande_id=_commande_id AND statut NOT IN ('acceptee','annulee');

  BEGIN
    UPDATE public.notifications SET lue=true, updated_at=now()
      WHERE document_id=_commande_id::text AND COALESCE(lue,false)=false;
  EXCEPTION WHEN undefined_column OR undefined_table THEN NULL; END;

  UPDATE public.commandes SET statut='annulee', notes=COALESCE(_motif, notes) WHERE commande_id=_commande_id;
  PERFORM public._recalc_solde_client_internal(v_cmd.client_id);
END; $function$;

CREATE OR REPLACE FUNCTION public.supprimer_facture_definitif(_facture_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_ref text; v_statut text; v_p int; v_p_valide int; v_client uuid;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT reference, statut, client_id INTO v_ref, v_statut, v_client FROM public.factures WHERE facture_id=_facture_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'Facture introuvable' USING ERRCODE='P0002'; END IF;
  IF v_statut <> 'annulee' THEN
    RAISE EXCEPTION 'Suppression refusée : la facture doit être annulée avant suppression définitive (statut actuel: %).', v_statut USING ERRCODE='P0001';
  END IF;
  SELECT count(*) INTO v_p_valide FROM public.paiements WHERE facture_id=_facture_id AND statut='valide';
  IF v_p_valide > 0 THEN
    RAISE EXCEPTION 'Suppression refusée : % paiement(s) validé(s) rattaché(s). Annuler les paiements d''abord.', v_p_valide USING ERRCODE='P0001';
  END IF;
  SELECT count(*) INTO v_p FROM public.paiements WHERE facture_id=_facture_id;
  DELETE FROM public.paiements WHERE facture_id=_facture_id;
  DELETE FROM public.factures WHERE facture_id=_facture_id;
  IF v_client IS NOT NULL THEN PERFORM public._recalc_solde_client_internal(v_client); END IF;
  RETURN jsonb_build_object('facture_id', _facture_id, 'reference', v_ref, 'motif', _motif, 'paiements_supprimes', v_p);
END; $function$;

-- LOT 3 : convertir_commande_en_bl idempotent + supprimer_colisage/livraison_suivi durcis
CREATE OR REPLACE FUNCTION public.convertir_commande_en_bl(
  _commande_id uuid, _nb_colis integer,
  _poids_total numeric DEFAULT NULL::numeric, _transporteur text DEFAULT NULL::text,
  _adresse_livraison text DEFAULT NULL::text, _signataire text DEFAULT NULL::text,
  _date_livraison date DEFAULT NULL::date, _decrementer_stock boolean DEFAULT true
) RETURNS TABLE(bl_id uuid, reference text)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_bl uuid; v_ref text; v_existing_bl uuid; v_existing_ref text;
  v_cmd public.commandes; r record; v_disponible numeric;
BEGIN
  PERFORM public.assert_permission('commandes.convertir_en_bl');
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id=_commande_id;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;

  SELECT b.bl_id, b.reference INTO v_existing_bl, v_existing_ref
    FROM public.bons_livraison b
    WHERE b.commande_id=_commande_id AND b.statut <> 'annulee'
    ORDER BY b.created_at DESC LIMIT 1;
  IF v_existing_bl IS NOT NULL THEN
    RETURN QUERY SELECT v_existing_bl, v_existing_ref; RETURN;
  END IF;

  IF _nb_colis IS NULL OR _nb_colis < 1 THEN RAISE EXCEPTION 'Nombre de colis invalide (>= 1 requis)'; END IF;
  v_ref := public._next_ref('BL', 'public.bons_livraison', 'reference');

  IF _decrementer_stock AND v_cmd.depot_id IS NOT NULL THEN
    FOR r IN SELECT cl.produit_id, cl.quantite, cl.designation FROM public.commande_lignes cl
             WHERE cl.commande_id=_commande_id AND cl.produit_id IS NOT NULL LOOP
      SELECT quantite INTO v_disponible FROM public.stocks_depots
        WHERE produit_id=r.produit_id AND depot_id=v_cmd.depot_id FOR UPDATE;
      IF v_disponible IS NULL OR v_disponible < r.quantite THEN
        RAISE EXCEPTION 'Stock insuffisant pour "%": disponible=%, demandé=%', r.designation, COALESCE(v_disponible,0), r.quantite USING ERRCODE='P0001';
      END IF;
    END LOOP;
  END IF;

  INSERT INTO public.bons_livraison(reference, commande_id, client_id, client_nom, date_emission, statut, exercice_id)
  VALUES (v_ref, _commande_id, v_cmd.client_id, v_cmd.client_nom, current_date, 'a_preparer', v_cmd.exercice_id)
  RETURNING bons_livraison.bl_id INTO v_bl;

  UPDATE public.commandes SET statut='livraison_en_cours' WHERE commande_id=_commande_id;

  IF _decrementer_stock AND v_cmd.depot_id IS NOT NULL THEN
    FOR r IN SELECT produit_id, quantite FROM public.commande_lignes WHERE commande_id=_commande_id AND produit_id IS NOT NULL LOOP
      UPDATE public.stocks_depots SET quantite=quantite-r.quantite, updated_at=now() WHERE produit_id=r.produit_id AND depot_id=v_cmd.depot_id;
      INSERT INTO public.stock_mouvements(produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie, stock_resultant, origine, document_id, user_id)
      SELECT r.produit_id, v_cmd.depot_id, 'sortie', r.quantite, 0, r.quantite, quantite, 'vente', _commande_id, auth.uid()
        FROM public.stocks_depots WHERE produit_id=r.produit_id AND depot_id=v_cmd.depot_id;
    END LOOP;
  END IF;
  RETURN QUERY SELECT v_bl, v_ref;
END; $function$;

CREATE OR REPLACE FUNCTION public.supprimer_colisage(_bl_id uuid, _motif text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_ref text; v_colis int; v_colis_ids uuid[]; v_lignes int:=0; v_hist int:=0;
BEGIN
  PERFORM public.assert_permission('colisage.supprimer');
  SELECT reference INTO v_ref FROM public.bons_livraison WHERE bl_id=_bl_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'BL introuvable' USING ERRCODE='P0002'; END IF;

  SELECT array_agg(colis_id), count(*) INTO v_colis_ids, v_colis FROM public.colis WHERE bl_id=_bl_id;
  IF v_colis_ids IS NOT NULL THEN
    SELECT count(*) INTO v_lignes FROM public.colis_lignes WHERE colis_id=ANY(v_colis_ids);
    SELECT count(*) INTO v_hist FROM public.colis_statut_historique WHERE colis_id=ANY(v_colis_ids) OR bl_id=_bl_id;
  END IF;

  INSERT INTO public.colis_statut_historique(bl_id, ancien_statut, nouveau_statut, motif, user_id)
  VALUES (_bl_id, 'colisage_termine', 'supprime', _motif, auth.uid());

  DELETE FROM public.colis WHERE bl_id=_bl_id;
  UPDATE public.bons_livraison SET statut='a_preparer' WHERE bl_id=_bl_id;

  RETURN jsonb_build_object('bl_id', _bl_id, 'reference', v_ref, 'motif', _motif,
    'colis_supprimes', COALESCE(v_colis,0), 'colis_lignes_supprimees', v_lignes,
    'colis_statut_historique_supprime', v_hist, 'bl_repasse_a_preparer', true);
END; $function$;

CREATE OR REPLACE FUNCTION public.supprimer_livraison_suivi(_id uuid, _motif text DEFAULT ''::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_row public.livsuivi_commandes; v_hist int;
BEGIN
  PERFORM public.assert_permission('livraison_suivi.supprimer');
  SELECT * INTO v_row FROM public.livsuivi_commandes WHERE id=_id;
  IF v_row.id IS NULL THEN RETURN NULL; END IF;
  SELECT count(*) INTO v_hist FROM public.livsuivi_historique WHERE livraison_id=_id;
  DELETE FROM public.livsuivi_commandes WHERE id=_id;
  RETURN jsonb_build_object('livraison_id', _id, 'commande_id', v_row.commande_id,
    'motif', _motif, 'historique_supprime', v_hist);
END; $function$;

-- Permissions RBAC
INSERT INTO public.rbac_permissions(code, libelle, module, action)
VALUES
  ('colisage.supprimer', 'Supprimer un colisage', 'colisage', 'supprimer'),
  ('livraison_suivi.supprimer', 'Supprimer un suivi de livraison', 'livraison_suivi', 'supprimer')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.id, p.code, true
FROM public.rbac_roles r CROSS JOIN public.rbac_permissions p
WHERE r.code='super_admin' AND p.code IN ('colisage.supprimer','livraison_suivi.supprimer')
ON CONFLICT DO NOTHING;

-- LOT 4 : supprimer_commande_definitif recalcule solde + drop colisages + historique informatif
CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
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
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT reference, client_id INTO v_ref, v_client_id FROM public.commandes WHERE commande_id=_commande_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'Bon de commande introuvable' USING ERRCODE='P0002'; END IF;

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

  RETURN jsonb_build_object('commande_id', _commande_id, 'reference', v_ref, 'motif', _motif,
    'lignes_supprimees', v_lignes, 'proformas_supprimees', v_proformas,
    'proforma_lignes_supprimees', v_pro_lignes, 'factures_supprimees', v_factures,
    'bls_supprimes', v_bls, 'paiements_supprimes', v_paiements,
    'livraisons_supprimees', v_livraisons+v_livraisons_commande, 'expeditions_supprimees', v_expeditions,
    'livsuivi_supprimees', v_livsuivi, 'colis_supprimes', v_colis,
    'retours_supprimes', v_retours, 'retour_lignes_supprimees', v_retour_lignes,
    'notifications_supprimees', v_notifications, 'stock_mouvements_supprimes', v_stock_mouvements,
    'solde_client_recalcule', v_client_id IS NOT NULL);
END; $function$;

CREATE OR REPLACE FUNCTION public.modifier_colis_lignes(_colis_id uuid, _lignes jsonb, _motif text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_ligne jsonb; v_bl_id uuid; v_bl_statut text; v_old_count int; v_new_count int;
BEGIN
  PERFORM public.assert_permission('colisage.modifier');
  SELECT c.bl_id, b.statut INTO v_bl_id, v_bl_statut
    FROM public.colis c LEFT JOIN public.bons_livraison b ON b.bl_id=c.bl_id
    WHERE c.colis_id=_colis_id;
  SELECT count(*) INTO v_old_count FROM public.colis_lignes WHERE colis_id=_colis_id;
  DELETE FROM public.colis_lignes WHERE colis_id=_colis_id;
  FOR v_ligne IN SELECT * FROM jsonb_array_elements(_lignes) LOOP
    INSERT INTO public.colis_lignes(colis_id, produit_id, designation, reference_produit, quantite)
    VALUES (_colis_id, NULLIF(v_ligne->>'produit_id','')::uuid, v_ligne->>'designation',
            v_ligne->>'reference_produit', COALESCE((v_ligne->>'quantite')::numeric, 0));
  END LOOP;
  SELECT count(*) INTO v_new_count FROM public.colis_lignes WHERE colis_id=_colis_id;
  INSERT INTO public.colis_statut_historique(colis_id, bl_id, ancien_statut, nouveau_statut, motif, user_id)
  VALUES (_colis_id, v_bl_id, COALESCE(v_bl_statut,'colisage_en_cours'),
          format('lignes_modifiees(%s→%s)', v_old_count, v_new_count), _motif, auth.uid());
END; $function$;

DROP TABLE IF EXISTS public.colisages CASCADE;
