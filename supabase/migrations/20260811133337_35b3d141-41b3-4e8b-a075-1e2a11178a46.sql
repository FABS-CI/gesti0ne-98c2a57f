
-- Migration: Normalisation numéros de retour et Workflow Statuts

-- 1. Mise à jour de retour_creer_demande pour le nouveau format RET-YYMMDD-XXX
CREATE OR REPLACE FUNCTION public.retour_creer_demande(_payload jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_retour_id uuid; v_appr_id uuid;
  v_user_nom text := public._current_user_display_name();
  v_client_id uuid := NULLIF(_payload->>'client_id','')::uuid;
  v_facture_id uuid := NULLIF(_payload->>'facture_id','')::uuid;
  v_livraison_id uuid := NULLIF(_payload->>'livraison_id','')::uuid;
  v_prefix text := 'RET-' || to_char(now(), 'YYMMDD') || '-';
  v_seq int;
  v_numero text;
  v_ligne jsonb; v_cli record; v_fac record;
  v_commande_id uuid; v_exercice_id uuid;
  v_qte numeric; v_pu numeric; v_rem numeric; v_dispo numeric;
  v_produit_id uuid; v_nb int := 0;
BEGIN
  IF NOT public.has_permission(auth.uid(),'retours.creer') THEN
    RAISE EXCEPTION 'Permission refusée : retours.creer' USING ERRCODE='insufficient_privilege';
  END IF;
  IF v_client_id IS NULL THEN RAISE EXCEPTION 'Le client est obligatoire'; END IF;
  IF v_facture_id IS NULL AND v_livraison_id IS NULL THEN
    RAISE EXCEPTION 'Un retour doit être rattaché à une facture ou à une livraison d''origine';
  END IF;

  -- Calcul du numéro séquentiel journalier
  SELECT COALESCE(MAX(SUBSTRING(numero FROM '-([0-9]{3})$')::int), 0) + 1 INTO v_seq
  FROM public.retours
  WHERE numero LIKE v_prefix || '%';
  
  v_numero := v_prefix || lpad(v_seq::text, 3, '0');

  SELECT nom, representant, telephone, ville, adresse INTO v_cli
  FROM public.clients WHERE client_id = v_client_id;

  IF v_facture_id IS NOT NULL THEN
    SELECT commande_id, exercice_id INTO v_fac FROM public.factures WHERE facture_id = v_facture_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Facture d''origine introuvable'; END IF;
    v_commande_id := v_fac.commande_id;
    v_exercice_id := v_fac.exercice_id;
  END IF;
  v_exercice_id := COALESCE(NULLIF(_payload->>'exercice_id','')::uuid, v_exercice_id,
                            (SELECT exercice_id FROM public.exercices_comptables
                             WHERE statut = 'ouvert' ORDER BY date_debut DESC LIMIT 1));

  INSERT INTO public.retours (
    reference, numero, date_retour, client_id, client_nom, etablissement,
    representant_nom, telephone, ville, adresse,
    commande_id, facture_id, livraison_id, motif, observations, notes,
    statut, created_by, created_by_nom, exercice_id, type_retour, depot_id
  ) VALUES (
    v_numero, v_numero,
    COALESCE(NULLIF(_payload->>'date_retour','')::date, CURRENT_DATE),
    v_client_id,
    COALESCE(NULLIF(_payload->>'client_nom',''), v_cli.nom),
    COALESCE(NULLIF(_payload->>'etablissement',''), v_cli.nom),
    COALESCE(NULLIF(_payload->>'representant_nom',''), v_cli.representant),
    COALESCE(NULLIF(_payload->>'telephone',''), v_cli.telephone),
    COALESCE(NULLIF(_payload->>'ville',''), v_cli.ville),
    COALESCE(NULLIF(_payload->>'adresse',''), v_cli.adresse),
    v_commande_id, v_facture_id, v_livraison_id,
    NULLIF(_payload->>'motif',''), NULLIF(_payload->>'observations',''),
    NULLIF(_payload->>'notes',''),
    'demande_creee', auth.uid(), v_user_nom, v_exercice_id,
    COALESCE(_payload->>'type_retour','physique'),
    NULLIF(_payload->>'depot_id','')::uuid
  ) RETURNING retour_id INTO v_retour_id;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb))
  LOOP
    v_produit_id := NULLIF(v_ligne->>'produit_id','')::uuid;
    v_qte := COALESCE((v_ligne->>'quantite')::numeric,(v_ligne->>'quantite_demandee')::numeric,0);
    IF v_produit_id IS NULL THEN RAISE EXCEPTION 'Chaque ligne doit référencer un produit'; END IF;
    IF v_qte <= 0 THEN
      RAISE EXCEPTION 'Quantité invalide pour « % » : elle doit être supérieure à 0',
        COALESCE(v_ligne->>'designation','produit');
    END IF;

    v_pu  := NULLIF(v_ligne->>'prix_unitaire','')::numeric;
    v_rem := COALESCE(NULLIF(v_ligne->>'remise_pct','')::numeric, 0);

    IF v_commande_id IS NOT NULL THEN
      SELECT cl.prix_unitaire, COALESCE(cl.remise_pct,0),
             GREATEST(cl.quantite::numeric - COALESCE((
               SELECT SUM(rl.quantite) FROM public.retour_lignes rl
               JOIN public.retours r2 ON r2.retour_id = rl.retour_id
               WHERE r2.facture_id = v_facture_id AND r2.statut NOT IN ('annule','rejete')
                 AND rl.produit_id = cl.produit_id),0), 0)
        INTO v_pu, v_rem, v_dispo
      FROM public.commande_lignes cl
      WHERE cl.commande_id = v_commande_id AND cl.produit_id = v_produit_id
      LIMIT 1;

      IF v_dispo IS NULL THEN
        RAISE EXCEPTION 'Le produit « % » ne figure pas sur le document d''origine',
          COALESCE(v_ligne->>'designation','produit');
      END IF;
      IF v_qte > v_dispo THEN
        RAISE EXCEPTION 'Quantité insuffisante sur le document d''origine pour « % » (dispo: %, demandée: %)',
          COALESCE(v_ligne->>'designation','produit'), v_dispo, v_qte;
      END IF;
    END IF;

    INSERT INTO public.retour_lignes (
      retour_id, produit_id, reference_produit, designation,
      quantite, quantite_demandee, prix_unitaire, remise_pct, motif
    ) VALUES (
      v_retour_id, v_produit_id, v_ligne->>'reference_produit',
      COALESCE(v_ligne->>'designation','produit'),
      v_qte, v_qte, COALESCE(v_pu,0), v_rem, v_ligne->>'motif'
    );
    v_nb := v_nb + 1;
  END LOOP;

  PERFORM public._retour_recalc_totaux(v_retour_id);

  -- Création de l'approbation workflow
  INSERT INTO public.workflow_approvals (
    workflow_code, module, entity_type, entity_id, reference,
    statut, demandeur_id, demandeur_nom, niveau_urgence, metadata
  ) VALUES (
    'retour_validation_demande', 'retour', 'retour', v_retour_id, v_numero,
    'en_attente', auth.uid(), v_user_nom,
    COALESCE(_payload->>'niveau_urgence','normal'),
    jsonb_build_object('client_id', v_client_id, 'nb_produits', v_nb, 'etape', 'demande')
  ) RETURNING id INTO v_appr_id;

  UPDATE public.retours SET workflow_approval_id = v_appr_id WHERE retour_id = v_retour_id;

  RETURN v_retour_id;
END;
$function$;

-- 2. Mise à jour de approbation_decider pour forcer le bon statut de retour (attente_reception)
CREATE OR REPLACE FUNCTION public.approbation_decider(p_approbation_id uuid, p_decision text, p_commentaire text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_appr public.workflow_approvals%ROWTYPE;
  v_nom text;
  v_new_statut text;
  v_is_approve boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;

  v_is_approve := p_decision IN ('approuve','approve','valider','valide');
  IF NOT v_is_approve AND p_decision NOT IN ('refuse','rejete','rejeter','refuser') THEN
    RAISE EXCEPTION 'Décision invalide';
  END IF;

  SELECT * INTO v_appr FROM public.workflow_approvals WHERE id = p_approbation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF v_appr.statut <> 'en_attente' THEN
    RAISE EXCEPTION 'Demande déjà statuée (%)', v_appr.statut;
  END IF;

  IF NOT (
    public.has_role_compat(v_uid, 'super_admin')
    OR public.has_role_compat(v_uid, 'admin')
    OR (v_is_approve     AND public.has_permission(v_uid, 'approbations.valider'))
    OR (NOT v_is_approve AND public.has_permission(v_uid, 'approbations.refuser'))
  ) THEN
    RAISE EXCEPTION 'Permission refusée';
  END IF;

  SELECT COALESCE(nom_complet, email, v_uid::text) INTO v_nom
    FROM public.profiles WHERE id = v_uid;

  v_new_statut := CASE WHEN v_is_approve THEN 'approuve' ELSE 'rejete' END;

  UPDATE public.workflow_approvals
     SET statut = v_new_statut,
         approbateur_id = v_uid,
         approbateur_nom = v_nom,
         commentaire = COALESCE(p_commentaire, commentaire),
         motif_refus = CASE WHEN NOT v_is_approve THEN p_commentaire ELSE motif_refus END,
         decided_at = now(),
         decision_details = jsonb_build_object(
           'decision', v_new_statut, 'by', v_uid, 'at', now(), 'commentaire', p_commentaire
         ),
         historique = COALESCE(historique,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
           'at', now(), 'by', v_uid, 'action', v_new_statut, 'commentaire', p_commentaire
         )),
         updated_at = now()
   WHERE id = p_approbation_id;

  IF v_is_approve THEN
    IF v_appr.module = 'paiements' THEN
      UPDATE public.paiements
         SET statut = 'valide', valide_par = v_uid, valide_le = now(),
             commentaire_validation = p_commentaire, updated_at = now()
       WHERE id = v_appr.entity_id;
    ELSIF v_appr.module = 'annulations' AND v_appr.entity_type = 'commande' THEN
      UPDATE public.commandes SET statut = 'annulee', updated_at = now()
       WHERE id = v_appr.entity_id;
    ELSIF v_appr.module = 'retour' THEN
      -- Correction : Un retour approuvé passe en 'attente_reception' (Magasin)
      UPDATE public.retours SET statut = 'attente_reception', updated_at = now() WHERE id = v_appr.entity_id;
    END IF;
  ELSE
    IF v_appr.module = 'paiements' THEN
      UPDATE public.paiements
         SET statut = 'rejete', rejete_par = v_uid, rejete_le = now(),
             motif_rejet = p_commentaire, updated_at = now()
       WHERE id = v_appr.entity_id;
    ELSIF v_appr.module = 'annulations' AND v_appr.entity_type = 'commande' THEN
      UPDATE public.commandes
         SET statut = COALESCE(v_appr.metadata->>'previous_statut', 'brouillon'),
             updated_at = now()
       WHERE id = v_appr.entity_id;
    ELSIF v_appr.module = 'retour' THEN
      UPDATE public.retours SET statut = 'refus_magasin', updated_at = now() WHERE id = v_appr.entity_id;
    END IF;
  END IF;

  INSERT INTO public.notifications(user_id, type_notification, titre, message, lien, metadata)
  VALUES (
    v_appr.demandeur_id,
    'approbation_' || v_new_statut,
    'Demande ' || CASE WHEN v_is_approve THEN 'approuvée' ELSE 'rejetée' END,
    COALESCE(v_appr.reference, v_appr.module) || COALESCE(' — ' || p_commentaire, ''),
    '/approbations',
    jsonb_build_object('approbation_id', p_approbation_id, 'module', v_appr.module)
  );

  RETURN jsonb_build_object('ok', true, 'statut', v_new_statut);
END;
$function$;
