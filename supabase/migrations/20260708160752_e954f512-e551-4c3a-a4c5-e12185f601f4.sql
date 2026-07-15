
-- =========================================================
-- Lot 5 — Suppression d'un approvisionnement (achat)
-- =========================================================
CREATE OR REPLACE FUNCTION public.supprimer_achat(_achat_id uuid, _motif text DEFAULT NULL)
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
BEGIN
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

  -- Mouvements de stock générés par cet achat
  SET LOCAL app.allow_stock_mouvement_delete = 'on';
  DELETE FROM public.stock_mouvements
   WHERE document_id = _achat_id AND document_table = 'achats';
  GET DIAGNOSTICS v_nb_stock = ROW_COUNT;
  RESET app.allow_stock_mouvement_delete;

  -- Écritures comptables liées (via source_type / source_id)
  DELETE FROM public.ecritures_comptables
   WHERE source_type = 'achat' AND source_id = _achat_id;
  GET DIAGNOSTICS v_nb_ecr = ROW_COUNT;

  DELETE FROM public.notifications
   WHERE document_id = _achat_id::text
     AND (document_type IS NULL OR document_type ILIKE '%achat%' OR module ILIKE '%achat%');
  GET DIAGNOSTICS v_nb_notifs = ROW_COUNT;

  -- Supprime l'achat (cascade sur achat_lignes)
  DELETE FROM public.achats WHERE achat_id = _achat_id;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user;
  v_summary := jsonb_build_object(
    'achat_id', _achat_id, 'reference', v_a.reference, 'motif', _motif,
    'lignes_supprimees', v_nb_lignes, 'stock_mouvements_supprimes', v_nb_stock,
    'ecritures_supprimees', v_nb_ecr, 'notifications_supprimees', v_nb_notifs,
    'role', CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END
  );
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (v_user, COALESCE(v_email,''), CASE WHEN v_is_admin THEN 'achat_supprime_super_admin' ELSE 'achat_supprime' END,
          'achats', _achat_id::text, to_jsonb(v_a), v_summary);
  RETURN v_summary;
END;
$function$;
GRANT EXECUTE ON FUNCTION public.supprimer_achat(uuid, text) TO authenticated;

-- =========================================================
-- Lot 6 — Suppression de référentiels avec garde
-- =========================================================
CREATE OR REPLACE FUNCTION public.supprimer_client(_client_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user uuid := auth.uid(); v_email text; v_is_admin boolean;
  v_c public.clients; v_refs jsonb; v_total int := 0;
BEGIN
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
GRANT EXECUTE ON FUNCTION public.supprimer_client(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.supprimer_fournisseur(_fournisseur_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_user uuid := auth.uid(); v_email text; v_f public.fournisseurs; v_nb int;
BEGIN
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
GRANT EXECUTE ON FUNCTION public.supprimer_fournisseur(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.supprimer_produit(_produit_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_user uuid := auth.uid(); v_email text; v_p public.produits; v_refs jsonb; v_total int;
BEGIN
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
GRANT EXECUTE ON FUNCTION public.supprimer_produit(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.supprimer_employe(_employe_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_user uuid := auth.uid(); v_email text; v_e public.employes; v_refs jsonb; v_total int;
BEGIN
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
GRANT EXECUTE ON FUNCTION public.supprimer_employe(uuid, text) TO authenticated;
