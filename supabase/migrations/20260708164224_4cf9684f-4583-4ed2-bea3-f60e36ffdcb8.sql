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
  DELETE FROM public.notifications WHERE document_id = _achat_id::text
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

CREATE OR REPLACE FUNCTION public.supprimer_client(_client_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user uuid := auth.uid(); v_email text; v_is_admin boolean;
  v_c public.clients; v_refs jsonb; v_total int := 0;
BEGIN PERFORM public.assert_permission('clients.supprimer');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE='28000'; END IF;
  SELECT * INTO v_c FROM public.clients WHERE client_id = _client_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Client introuvable'; END IF;
  v_is_admin := public.has_role(v_user,'super_admin'::public.app_role);
  SELECT jsonb_build_object(
    'commandes', (SELECT count(*) FROM public.commandes WHERE client_id=_client_id),
    'factures', (SELECT count(*) FROM public.factures WHERE client_id=_client_id),
    'paiements', (SELECT count(*) FROM public.paiements p JOIN public.factures f ON f.facture_id=p.facture_id WHERE f.client_id=_client_id),
    'bons_livraison', (SELECT count(*) FROM public.bons_livraison WHERE client_id=_client_id),
    'retours', (SELECT count(*) FROM public.retours WHERE client_id=_client_id),
    'specimens', (SELECT count(*) FROM public.specimens WHERE client_id=_client_id)
  ) INTO v_refs;
  SELECT COALESCE(SUM((value)::int),0) INTO v_total FROM jsonb_each_text(v_refs);
  IF v_total > 0 THEN
    RAISE EXCEPTION 'Suppression interdite : ce client possède des données liées (%). Désactivez-le à la place.', v_refs::text
      USING ERRCODE='foreign_key_violation';
  END IF;
  DELETE FROM public.clients WHERE client_id = _client_id;
  SELECT email INTO v_email FROM auth.users WHERE id = v_user;
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (v_user, COALESCE(v_email,''), 'client_supprime', 'clients', _client_id::text, to_jsonb(v_c),
    jsonb_build_object('motif', _motif, 'references', v_refs));
  RETURN jsonb_build_object('client_id', _client_id, 'nom', v_c.nom, 'motif', _motif);
END;
$function$;

CREATE OR REPLACE FUNCTION public.supprimer_employe(_employe_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_user uuid := auth.uid(); v_email text; v_e public.employes; v_refs jsonb; v_total int;
BEGIN PERFORM public.assert_permission('employes.supprimer');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE='28000'; END IF;
  SELECT * INTO v_e FROM public.employes WHERE employe_id=_employe_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Employé introuvable'; END IF;
  SELECT jsonb_build_object(
    'contrats',(SELECT count(*) FROM public.contrats WHERE employe_id=_employe_id),
    'bulletins_paie',(SELECT count(*) FROM public.bulletins_paie WHERE employe_id=_employe_id),
    'conges',(SELECT count(*) FROM public.conges WHERE employe_id=_employe_id),
    'missions',(SELECT count(*) FROM public.missions WHERE employe_id=_employe_id),
    'evaluations',(SELECT count(*) FROM public.evaluations WHERE employe_id=_employe_id),
    'colisage_responsables',(SELECT count(*) FROM public.colisage_responsables WHERE employe_id=_employe_id)
  ) INTO v_refs;
  SELECT COALESCE(SUM((value)::int),0) INTO v_total FROM jsonb_each_text(v_refs);
  IF v_total > 0 THEN
    RAISE EXCEPTION 'Suppression interdite : cet employé a des enregistrements liés (%). Désactivez-le à la place.', v_refs::text
      USING ERRCODE='foreign_key_violation';
  END IF;
  DELETE FROM public.employes WHERE employe_id=_employe_id;
  SELECT email INTO v_email FROM auth.users WHERE id=v_user;
  INSERT INTO public.audit_logs(user_id,user_email,action,table_name,record_id,old_values,new_values)
  VALUES (v_user,COALESCE(v_email,''),'employe_supprime','employes',_employe_id::text,to_jsonb(v_e),
    jsonb_build_object('motif',_motif,'references',v_refs));
  RETURN jsonb_build_object('employe_id',_employe_id,'motif',_motif);
END;
$function$;

CREATE OR REPLACE FUNCTION public.supprimer_fournisseur(_fournisseur_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_user uuid := auth.uid(); v_email text; v_f public.fournisseurs; v_nb int;
BEGIN PERFORM public.assert_permission('fournisseurs.supprimer');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE='28000'; END IF;
  SELECT * INTO v_f FROM public.fournisseurs WHERE fournisseur_id=_fournisseur_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Fournisseur introuvable'; END IF;
  SELECT count(*) INTO v_nb FROM public.achats WHERE fournisseur_id=_fournisseur_id;
  IF v_nb > 0 THEN
    RAISE EXCEPTION 'Suppression interdite : % approvisionnement(s) lié(s). Désactivez le fournisseur à la place.', v_nb
      USING ERRCODE='foreign_key_violation';
  END IF;
  DELETE FROM public.fournisseurs WHERE fournisseur_id=_fournisseur_id;
  SELECT email INTO v_email FROM auth.users WHERE id=v_user;
  INSERT INTO public.audit_logs(user_id,user_email,action,table_name,record_id,old_values,new_values)
  VALUES (v_user,COALESCE(v_email,''),'fournisseur_supprime','fournisseurs',_fournisseur_id::text,to_jsonb(v_f),
    jsonb_build_object('motif',_motif));
  RETURN jsonb_build_object('fournisseur_id',_fournisseur_id,'nom',v_f.nom,'motif',_motif);
END;
$function$;

CREATE OR REPLACE FUNCTION public.supprimer_produit(_produit_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_user uuid := auth.uid(); v_email text; v_p public.produits; v_refs jsonb; v_total int;
BEGIN PERFORM public.assert_permission('produits.supprimer');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE='28000'; END IF;
  SELECT * INTO v_p FROM public.produits WHERE produit_id=_produit_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Produit introuvable'; END IF;
  SELECT jsonb_build_object(
    'commande_lignes',(SELECT count(*) FROM public.commande_lignes WHERE produit_id=_produit_id),
    'achat_lignes',(SELECT count(*) FROM public.achat_lignes WHERE produit_id=_produit_id),
    'stock_mouvements',(SELECT count(*) FROM public.stock_mouvements WHERE produit_id=_produit_id),
    'inventaire_lignes',(SELECT count(*) FROM public.inventaire_lignes WHERE produit_id=_produit_id),
    'specimen_lignes',(SELECT count(*) FROM public.specimen_lignes WHERE produit_id=_produit_id),
    'retour_lignes',(SELECT count(*) FROM public.retour_lignes WHERE produit_id=_produit_id)
  ) INTO v_refs;
  SELECT COALESCE(SUM((value)::int),0) INTO v_total FROM jsonb_each_text(v_refs);
  IF v_total > 0 THEN
    RAISE EXCEPTION 'Suppression interdite : ce produit est utilisé (%). Désactivez-le à la place.', v_refs::text
      USING ERRCODE='foreign_key_violation';
  END IF;
  DELETE FROM public.produits WHERE produit_id=_produit_id;
  SELECT email INTO v_email FROM auth.users WHERE id=v_user;
  INSERT INTO public.audit_logs(user_id,user_email,action,table_name,record_id,old_values,new_values)
  VALUES (v_user,COALESCE(v_email,''),'produit_supprime','produits',_produit_id::text,to_jsonb(v_p),
    jsonb_build_object('motif',_motif,'references',v_refs));
  RETURN jsonb_build_object('produit_id',_produit_id,'motif',_motif);
END;
$function$;

CREATE OR REPLACE FUNCTION public.supprimer_facture_definitif(_facture_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  _f public.factures%ROWTYPE;
  _user uuid := auth.uid();
  _email text;
  _nb_paie int;
  _nb_fne int;
BEGIN PERFORM public.assert_permission('factures.supprimer');
  IF _user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000'; END IF;
  IF NOT public.has_role(_user, 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'Suppression réservée au Super Administrateur' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO _f FROM public.factures WHERE facture_id = _facture_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Facture introuvable' USING ERRCODE = 'P0002'; END IF;
  IF COALESCE(_f.montant_paye,0) > 0 OR _f.statut IN ('payee','partielle') THEN
    RAISE EXCEPTION 'Suppression interdite: facture % réglée ou partiellement payée', _f.reference USING ERRCODE = 'check_violation';
  END IF;
  SELECT count(*) INTO _nb_paie FROM public.paiements WHERE facture_id = _facture_id;
  IF _nb_paie > 0 THEN
    RAISE EXCEPTION 'Suppression interdite: paiements enregistrés sur la facture %', _f.reference USING ERRCODE = 'check_violation';
  END IF;
  SELECT count(*) INTO _nb_fne FROM public.fne_factures
    WHERE facture_id = _facture_id AND statut IN ('valide','soumis','submitted','validated','accepted');
  IF _nb_fne > 0 THEN
    RAISE EXCEPTION 'Suppression interdite: facture % déjà transmise à la FNE', _f.reference USING ERRCODE = 'check_violation';
  END IF;
  SELECT email INTO _email FROM auth.users WHERE id = _user;
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (_user, _email, 'delete_facture_definitif', 'factures', _facture_id::text, to_jsonb(_f),
    jsonb_build_object('motif', _motif, 'role', 'super_admin', 'reference', _f.reference));
  DELETE FROM public.fne_factures WHERE facture_id = _facture_id;
  UPDATE public.bons_retour SET facture_id = NULL WHERE facture_id = _facture_id;
  UPDATE public.retours SET facture_id = NULL WHERE facture_id = _facture_id;
  DELETE FROM public.factures WHERE facture_id = _facture_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.supprimer_proforma_definitif(_proforma_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  _p public.proformas%ROWTYPE;
  _user uuid := auth.uid();
  _email text;
BEGIN PERFORM public.assert_permission('proformas.supprimer');
  IF _user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000'; END IF;
  IF NOT public.has_role(_user, 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'Suppression réservée au Super Administrateur' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO _p FROM public.proformas WHERE proforma_id = _proforma_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Proforma introuvable' USING ERRCODE = 'P0002'; END IF;
  IF _p.statut IN ('transformee','facturee') THEN
    RAISE EXCEPTION 'Suppression interdite: proforma % déjà transformée en facture', _p.reference USING ERRCODE = 'check_violation';
  END IF;
  SELECT email INTO _email FROM auth.users WHERE id = _user;
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (_user, _email, 'delete_proforma_definitif', 'proformas', _proforma_id::text, to_jsonb(_p),
    jsonb_build_object('motif', _motif, 'role', 'super_admin', 'reference', _p.reference));
  DELETE FROM public.proforma_lignes WHERE proforma_id = _proforma_id;
  DELETE FROM public.proformas WHERE proforma_id = _proforma_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.valider_inventaire_physique(_inventaire_id uuid, _lignes jsonb)
 RETURNS inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$ DECLARE inv public.inventaires; l jsonb;
BEGIN PERFORM public.assert_permission('inventaires.valider');
  FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_lignes,'[]'::jsonb)) LOOP
    UPDATE public.inventaire_lignes SET quantite_comptee=(l->>'quantite_comptee')::int,
      stock_compte=(l->>'quantite_comptee')::int,
      ecart=(l->>'quantite_comptee')::int-stock_theorique,
      valeur_ecart=((l->>'quantite_comptee')::int-stock_theorique)*valeur_unitaire,
      observation=l->>'observation'
    WHERE ligne_id=(l->>'ligne_id')::uuid;
  END LOOP;
  UPDATE public.inventaires SET statut='valide',validated_at=now(),
    nb_ecarts=(SELECT count(*) FROM public.inventaire_lignes WHERE inventaire_id=_inventaire_id AND coalesce(ecart,0)<>0),
    valeur_totale=(SELECT coalesce(sum(abs(valeur_ecart)),0) FROM public.inventaire_lignes WHERE inventaire_id=_inventaire_id),
    updated_at=now()
  WHERE inventaire_id=_inventaire_id RETURNING * INTO inv;
  RETURN inv;
END $function$;

CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
 RETURNS TABLE(facture_reference text, bl_reference text)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE c record; f_ref text; b_ref text; l record; v_depot uuid; v_actuel int; v_bl_id uuid;
BEGIN PERFORM public.assert_permission('commandes.valider');
  SELECT * INTO c FROM public.commandes WHERE commande_id=_commande_id;
  v_depot := public.resolve_depot_sortie(c.depot_id, 'commandes');
  FOR l IN SELECT produit_id,quantite FROM public.commande_lignes
            WHERE commande_id=_commande_id AND produit_id IS NOT NULL LOOP
    INSERT INTO public.stocks_depots(produit_id,depot_id,quantite) VALUES(l.produit_id,v_depot,0)
      ON CONFLICT(produit_id,depot_id) DO NOTHING;
    SELECT COALESCE(quantite,0) INTO v_actuel FROM public.stocks_depots
      WHERE produit_id=l.produit_id AND depot_id=v_depot FOR UPDATE;
    PERFORM public.ajuster_stock_depot(l.produit_id, v_depot, GREATEST(v_actuel-l.quantite,0),
      'Vente commande '||c.reference, 'commande', _commande_id, c.reference, 'commandes', NULL);
  END LOOP;
  UPDATE public.commandes SET statut='validee',depot_id=v_depot,updated_at=now() WHERE commande_id=_commande_id;
  INSERT INTO public.factures(client_id,client_nom,commande_id,montant_total,montant_paye,statut,notes)
    VALUES(c.client_id,c.client_nom,_commande_id,c.montant_total,0,'impayee','Facturation de la commande '||c.reference)
    RETURNING reference INTO f_ref;
  INSERT INTO public.bons_livraison(commande_id,client_id,montant_total,statut,adresse_livraison)
    VALUES(_commande_id,c.client_id,c.montant_total,'brouillon',c.adresse)
    RETURNING bl_id, reference INTO v_bl_id, b_ref;
  PERFORM public.creer_livraison_commande(_commande_id);
  UPDATE public.livraisons_commande SET statut='preparation', bl_id=v_bl_id WHERE commande_id=_commande_id;
  facture_reference:=f_ref; bl_reference:=b_ref; RETURN NEXT;
END $function$;

CREATE OR REPLACE FUNCTION public.valider_decaissement_tournee(_tournee_id uuid, _mode_reglement text, _commentaire text DEFAULT NULL::text)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_t public.tournees;
  v_exercice_id uuid;
  v_journal text;
  v_compte_tresorerie text;
  v_libelle_tresorerie text;
  v_ecriture_id uuid;
  v_ref text;
BEGIN PERFORM public.assert_permission('tournees.valider');
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé : seule la comptabilité peut valider un décaissement.';
  END IF;
  IF _mode_reglement NOT IN ('caisse','banque') THEN
    RAISE EXCEPTION 'Mode de règlement invalide (caisse ou banque attendu).';
  END IF;
  SELECT * INTO v_t FROM public.tournees WHERE tournee_id = _tournee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tournée introuvable.'; END IF;
  IF v_t.validation_statut = 'decaisse' THEN RAISE EXCEPTION 'Cette tournée est déjà décaissée.'; END IF;
  IF COALESCE(v_t.cout_total,0) <= 0 THEN RAISE EXCEPTION 'Aucun coût à valider pour cette tournée.'; END IF;
  IF _mode_reglement = 'caisse' THEN
    v_journal := 'CA'; v_compte_tresorerie := '571'; v_libelle_tresorerie := 'Caisse';
  ELSE
    v_journal := 'BQ'; v_compte_tresorerie := '521'; v_libelle_tresorerie := 'Banque';
  END IF;
  SELECT exercice_id INTO v_exercice_id FROM public.exercices
    WHERE v_t.date_tournee BETWEEN date_debut AND date_fin ORDER BY date_debut DESC LIMIT 1;
  IF v_exercice_id IS NULL THEN
    SELECT exercice_id INTO v_exercice_id FROM public.exercices WHERE statut = 'actif' ORDER BY date_debut DESC LIMIT 1;
  END IF;
  IF v_exercice_id IS NULL THEN RAISE EXCEPTION 'Aucun exercice comptable ouvert pour la date de la tournée.'; END IF;
  v_ref := 'DEC-' || v_t.reference;
  INSERT INTO public.ecritures_comptables (reference, date_ecriture, journal, libelle, source_type, source_id, montant_total, exercice_id)
  VALUES (v_ref, v_t.date_tournee, v_journal, 'Décaissement tournée ' || v_t.reference,
    'tournee', v_t.tournee_id, v_t.cout_total, v_exercice_id) RETURNING ecriture_id INTO v_ecriture_id;
  IF COALESCE(v_t.cout_carburant,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6241', 'Carburant', v_t.cout_carburant, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_peages,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6242', 'Péages', v_t.cout_peages, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_repas,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6256', 'Repas / Missions', v_t.cout_repas, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_manutentions,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6244', 'Manutention', v_t.cout_manutentions, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_expeditions,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6245', 'Expéditions / Transport', v_t.cout_expeditions, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_livraison,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6246', 'Frais de livraison', v_t.cout_livraison, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_autres,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6288', 'Autres frais logistiques', v_t.cout_autres, 0, v_t.tournee_id);
  END IF;
  INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
  VALUES (v_ecriture_id, v_compte_tresorerie, v_libelle_tresorerie, 0, v_t.cout_total, v_t.tournee_id);
  UPDATE public.tournees SET
    validation_statut = 'decaisse', validation_at = now(), validation_by = auth.uid(),
    validation_commentaire = COALESCE(_commentaire, validation_commentaire),
    mode_reglement = _mode_reglement, ecriture_id = v_ecriture_id,
    updated_at = now(), updated_by = auth.uid()
  WHERE tournee_id = _tournee_id;
  INSERT INTO public.couts_logistiques_audit(tournee_id, action, ancien_statut, nouveau_statut, commentaire, user_id)
  VALUES (_tournee_id, 'decaissement', v_t.validation_statut, 'decaisse',
    'Écriture ' || v_ref || ' générée (' || v_journal || ')', auth.uid());
  RETURN v_ecriture_id;
END;
$function$;