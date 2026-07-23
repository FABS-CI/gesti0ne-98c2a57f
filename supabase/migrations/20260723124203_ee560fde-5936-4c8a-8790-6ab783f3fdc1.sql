
CREATE OR REPLACE FUNCTION public._current_user_display_name()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT nom_complet FROM public.profiles WHERE id = auth.uid() LIMIT 1),
    (SELECT email FROM public.profiles WHERE id = auth.uid() LIMIT 1),
    'utilisateur'
  );
$$;

CREATE OR REPLACE FUNCTION public._notifier_role(
  _role_code text, _titre text, _message text, _lien text,
  _module text, _document_type text, _document_id uuid, _document_reference text
) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO public.notifications (
    titre, message, type_notification, priorite, module,
    lien, document_type, document_id, document_reference, user_id, role_cible
  )
  SELECT _titre, _message, 'workflow', 'normal', _module,
         _lien, _document_type, _document_id, _document_reference,
         ur.user_id, _role_code
  FROM public.rbac2_user_roles ur
  WHERE ur.role_code = _role_code AND ur.user_id IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION public.retour_creer_demande(_payload jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_retour_id uuid; v_appr_id uuid;
  v_user_nom text := public._current_user_display_name();
  v_client_id uuid := (_payload->>'client_id')::uuid;
  v_numero text := 'RET-'||to_char(now(),'YYYYMMDD')||'-'||substr(gen_random_uuid()::text,1,6);
  v_ligne jsonb;
BEGIN
  IF NOT public.has_permission(auth.uid(),'retours.creer') THEN
    RAISE EXCEPTION 'Permission refusée : retours.creer' USING ERRCODE='insufficient_privilege';
  END IF;
  IF v_client_id IS NULL THEN RAISE EXCEPTION 'client_id obligatoire'; END IF;

  INSERT INTO public.retours (
    reference, numero, client_id, client_nom, commande_id, facture_id,
    motif, statut, notes, created_by, created_by_nom,
    exercice_id, type_retour, depot_id
  ) VALUES (
    v_numero, v_numero, v_client_id, _payload->>'client_nom',
    NULLIF(_payload->>'commande_id','')::uuid, NULLIF(_payload->>'facture_id','')::uuid,
    _payload->>'motif','demande_creee',_payload->>'notes',
    auth.uid(), v_user_nom,
    NULLIF(_payload->>'exercice_id','')::uuid,
    COALESCE(_payload->>'type_retour','physique'),
    NULLIF(_payload->>'depot_id','')::uuid
  ) RETURNING retour_id INTO v_retour_id;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb))
  LOOP
    INSERT INTO public.retour_lignes (
      retour_id, produit_id, designation, reference_produit,
      quantite, quantite_demandee, prix_unitaire, total_ligne, motif
    ) VALUES (
      v_retour_id, NULLIF(v_ligne->>'produit_id','')::uuid,
      v_ligne->>'designation', v_ligne->>'reference_produit',
      COALESCE((v_ligne->>'quantite')::numeric,0),
      COALESCE((v_ligne->>'quantite')::numeric,0),
      COALESCE((v_ligne->>'prix_unitaire')::numeric,0),
      COALESCE((v_ligne->>'quantite')::numeric,0)*COALESCE((v_ligne->>'prix_unitaire')::numeric,0),
      v_ligne->>'motif'
    );
  END LOOP;

  INSERT INTO public.workflow_approvals (
    workflow_code, module, entity_type, entity_id, reference,
    statut, demandeur_id, demandeur_nom, metadata
  ) VALUES (
    'retour_reception','retours','retour',v_retour_id,v_numero,
    'en_attente', auth.uid(), v_user_nom,
    jsonb_build_object('etape','reception_magasin')
  ) RETURNING id INTO v_appr_id;

  UPDATE public.retours SET workflow_approval_id=v_appr_id, statut='attente_reception'
  WHERE retour_id=v_retour_id;

  PERFORM public._notifier_role('gestionnaire_stock','Nouveau retour à réceptionner',
    'Retour '||v_numero,'/retours/'||v_retour_id,'retours','retour',v_retour_id,v_numero);
  PERFORM public._notifier_role('responsable_magasinier','Nouveau retour à réceptionner',
    'Retour '||v_numero,'/retours/'||v_retour_id,'retours','retour',v_retour_id,v_numero);

  RETURN v_retour_id;
END$$;

CREATE OR REPLACE FUNCTION public.retour_receptionner(
  _retour_id uuid, _version integer, _lignes jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_retour public.retours; v_user_nom text := public._current_user_display_name();
  v_ligne jsonb; v_appr_id uuid; v_numero text;
BEGIN
  IF NOT public.has_permission(auth.uid(),'retours.receptionner') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;
  SELECT * INTO v_retour FROM public.retours WHERE retour_id=_retour_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Retour introuvable'; END IF;
  IF v_retour.version_no <> _version THEN
    RAISE EXCEPTION 'CONFLIT_VERSION' USING ERRCODE='serialization_failure';
  END IF;
  IF v_retour.statut NOT IN ('demande_creee','attente_reception') THEN
    RAISE EXCEPTION 'Statut invalide : %', v_retour.statut;
  END IF;
  v_numero := COALESCE(v_retour.numero,v_retour.reference,_retour_id::text);

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(_lignes) LOOP
    UPDATE public.retour_lignes SET
      quantite_recue = COALESCE((v_ligne->>'quantite_recue')::numeric,0),
      etat_reception = COALESCE(v_ligne->>'etat_reception','conforme'),
      commentaire_reception = v_ligne->>'commentaire_reception'
    WHERE ligne_id = (v_ligne->>'ligne_id')::uuid;

    IF v_retour.depot_id IS NOT NULL
       AND COALESCE((v_ligne->>'quantite_recue')::numeric,0) > 0
       AND COALESCE(v_ligne->>'etat_reception','conforme')='conforme'
       AND NULLIF(v_ligne->>'produit_id','') IS NOT NULL THEN
      INSERT INTO public.stock_mouvements (
        produit_id, depot_id, type, quantite, quantite_entree,
        motif, origine, document_id, document_reference, document_table,
        user_id, user_nom
      ) VALUES (
        (v_ligne->>'produit_id')::uuid, v_retour.depot_id,
        'entree', COALESCE((v_ligne->>'quantite_recue')::numeric,0),
        COALESCE((v_ligne->>'quantite_recue')::numeric,0),
        'Retour client', 'retour', _retour_id, v_numero, 'retours',
        auth.uid(), v_user_nom
      );
      INSERT INTO public.stocks_depots (produit_id, depot_id, quantite)
      VALUES ((v_ligne->>'produit_id')::uuid, v_retour.depot_id,
              COALESCE((v_ligne->>'quantite_recue')::numeric,0))
      ON CONFLICT (produit_id, depot_id) DO UPDATE
        SET quantite = public.stocks_depots.quantite + EXCLUDED.quantite, updated_at=now();
    END IF;
  END LOOP;

  UPDATE public.retours SET
    statut='attente_validation_compta', receptionne_par=auth.uid(),
    receptionne_par_nom=v_user_nom, receptionne_at=now(),
    version_no=version_no+1, updated_at=now()
  WHERE retour_id=_retour_id;

  UPDATE public.workflow_approvals SET
    statut='valide', approbateur_id=auth.uid(), approbateur_nom=v_user_nom,
    decided_at=now(), version_no=version_no+1
  WHERE id=v_retour.workflow_approval_id;

  INSERT INTO public.workflow_approvals (
    workflow_code, module, entity_type, entity_id, reference,
    statut, demandeur_id, demandeur_nom, metadata
  ) VALUES (
    'retour_valider_compta','retours','retour',_retour_id,v_numero,
    'en_attente', auth.uid(), v_user_nom,
    jsonb_build_object('etape','validation_comptable')
  ) RETURNING id INTO v_appr_id;

  UPDATE public.retours SET workflow_approval_id=v_appr_id WHERE retour_id=_retour_id;

  PERFORM public._notifier_role('comptable','Retour à valider financièrement',
    'Retour '||v_numero||' réceptionné','/approbations/'||v_appr_id,
    'retours','retour',_retour_id,v_numero);
END$$;

CREATE OR REPLACE FUNCTION public.retour_refuser_magasin(
  _retour_id uuid, _version integer, _motif text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_retour public.retours; v_user_nom text := public._current_user_display_name();
BEGIN
  IF NOT public.has_permission(auth.uid(),'retours.refuser_magasin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;
  IF COALESCE(trim(_motif),'')='' THEN RAISE EXCEPTION 'Motif obligatoire'; END IF;
  SELECT * INTO v_retour FROM public.retours WHERE retour_id=_retour_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Retour introuvable'; END IF;
  IF v_retour.version_no <> _version THEN
    RAISE EXCEPTION 'CONFLIT_VERSION' USING ERRCODE='serialization_failure';
  END IF;
  IF v_retour.statut NOT IN ('demande_creee','attente_reception') THEN
    RAISE EXCEPTION 'Statut invalide : %', v_retour.statut;
  END IF;
  UPDATE public.retours SET statut='refus_magasin', motif_refus_magasin=_motif,
    receptionne_par=auth.uid(), receptionne_par_nom=v_user_nom, receptionne_at=now(),
    version_no=version_no+1, updated_at=now() WHERE retour_id=_retour_id;
  UPDATE public.workflow_approvals SET statut='refuse', motif_refus=_motif,
    approbateur_id=auth.uid(), approbateur_nom=v_user_nom, decided_at=now()
  WHERE id=v_retour.workflow_approval_id;
  INSERT INTO public.notifications(titre,message,type_notification,priorite,module,lien,document_type,document_id,document_reference,user_id)
  VALUES ('Retour refusé (magasin)','Motif : '||_motif,'workflow','normal','retours',
          '/retours/'||_retour_id,'retour',_retour_id,
          COALESCE(v_retour.numero,v_retour.reference), v_retour.created_by);
END$$;

CREATE OR REPLACE FUNCTION public.retour_simulation_financiere(_retour_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_retour public.retours; v_facture public.factures;
  v_paiements jsonb; v_lignes jsonb;
  v_valeur numeric; v_paye numeric := 0; v_reste numeric := 0;
BEGIN
  IF NOT public.has_permission(auth.uid(),'approbations.voir') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;
  SELECT * INTO v_retour FROM public.retours WHERE retour_id=_retour_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Retour introuvable'; END IF;

  IF v_retour.facture_id IS NOT NULL THEN
    SELECT * INTO v_facture FROM public.factures WHERE facture_id=v_retour.facture_id;
    v_paye := COALESCE(v_facture.montant_paye,0);
    v_reste := COALESCE(v_facture.montant_total,0) - v_paye;
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'paiement_id',paiement_id,'date',date_paiement,
      'montant',montant,'mode',mode_paiement,'statut',statut
    ) ORDER BY date_paiement),'[]'::jsonb) INTO v_paiements
    FROM public.paiements WHERE facture_id=v_retour.facture_id;
  ELSE v_paiements := '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'ligne_id',ligne_id,'produit_id',produit_id,
    'designation',designation,'reference_produit',reference_produit,
    'quantite_demandee',COALESCE(quantite_demandee,quantite),
    'quantite_recue',COALESCE(quantite_recue,0),
    'etat_reception',etat_reception,'prix_unitaire',prix_unitaire,
    'valeur_retour',COALESCE(quantite_recue,quantite,0)*COALESCE(prix_unitaire,0)
  )),'[]'::jsonb) INTO v_lignes
  FROM public.retour_lignes WHERE retour_id=_retour_id;

  SELECT COALESCE(SUM(COALESCE(quantite_recue,quantite,0)*COALESCE(prix_unitaire,0)),0)
  INTO v_valeur FROM public.retour_lignes WHERE retour_id=_retour_id;

  RETURN jsonb_build_object(
    'retour',to_jsonb(v_retour),'facture',to_jsonb(v_facture),
    'montant_paye',v_paye,'montant_restant',v_reste,
    'paiements',v_paiements,'lignes',v_lignes,'valeur_retour',v_valeur,
    'impacts', jsonb_build_object(
      'diminuer_solde', jsonb_build_object('solde_client_delta',-v_valeur),
      'creer_avoir', jsonb_build_object('avoir_montant',v_valeur),
      'preparer_remboursement', jsonb_build_object('remboursement_montant',LEAST(v_valeur,v_paye)),
      'aucun_impact', jsonb_build_object('note','Aucun impact comptable')
    )
  );
END$$;

CREATE OR REPLACE FUNCTION public.retour_valider_compta(
  _retour_id uuid, _version integer, _option text, _montants jsonb, _commentaire text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_retour public.retours; v_user_nom text := public._current_user_display_name();
  v_valeur numeric := COALESCE((_montants->>'valeur_retour')::numeric,0);
BEGIN
  IF NOT public.has_permission(auth.uid(),'retours.valider_compta') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;
  IF _option NOT IN ('diminuer_solde','creer_avoir','preparer_remboursement','aucun_impact') THEN
    RAISE EXCEPTION 'Option invalide : %', _option;
  END IF;
  SELECT * INTO v_retour FROM public.retours WHERE retour_id=_retour_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Retour introuvable'; END IF;
  IF v_retour.version_no <> _version THEN
    RAISE EXCEPTION 'CONFLIT_VERSION' USING ERRCODE='serialization_failure';
  END IF;
  IF v_retour.statut <> 'attente_validation_compta' THEN
    RAISE EXCEPTION 'Statut invalide : %', v_retour.statut;
  END IF;
  IF v_retour.exercice_id IS NOT NULL THEN
    IF EXISTS(SELECT 1 FROM public.exercices_comptables
              WHERE exercice_id=v_retour.exercice_id AND statut='cloture') THEN
      RAISE EXCEPTION 'Exercice comptable clôturé';
    END IF;
  END IF;

  IF _option='diminuer_solde' AND v_retour.client_id IS NOT NULL THEN
    UPDATE public.clients SET solde=COALESCE(solde,0)-v_valeur, updated_at=now()
    WHERE client_id=v_retour.client_id;
  END IF;
  IF _option='creer_avoir' AND v_retour.facture_id IS NOT NULL THEN
    INSERT INTO public.factures (
      reference, client_id, client_nom, commande_id, exercice_id,
      date_facture, montant_total, statut, notes
    ) VALUES (
      'AV-'||to_char(now(),'YYYYMMDD')||'-'||substr(gen_random_uuid()::text,1,6),
      v_retour.client_id, v_retour.client_nom, v_retour.commande_id, v_retour.exercice_id,
      CURRENT_DATE, -v_valeur, 'avoir',
      'Avoir sur retour '||COALESCE(v_retour.numero,v_retour.reference)
    );
  END IF;

  UPDATE public.retours SET statut='cloture',
    valide_compta_par=auth.uid(), valide_compta_par_nom=v_user_nom,
    valide_compta_at=now(), version_no=version_no+1, updated_at=now()
  WHERE retour_id=_retour_id;

  UPDATE public.workflow_approvals SET
    statut='valide', approbateur_id=auth.uid(), approbateur_nom=v_user_nom,
    decided_at=now(), commentaire=_commentaire,
    decision_details=jsonb_build_object('option',_option,'montants',_montants),
    simulation_financiere=_montants
  WHERE id=v_retour.workflow_approval_id;

  INSERT INTO public.notifications(titre,message,type_notification,priorite,module,lien,document_type,document_id,document_reference,user_id)
  VALUES ('Retour validé financièrement',
          'Option : '||_option||' - Montant : '||v_valeur::text,
          'workflow','normal','retours','/retours/'||_retour_id,
          'retour',_retour_id, COALESCE(v_retour.numero,v_retour.reference), v_retour.created_by);
END$$;

CREATE OR REPLACE FUNCTION public.retour_refuser_compta(
  _retour_id uuid, _version integer, _motif text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_retour public.retours; v_user_nom text := public._current_user_display_name();
BEGIN
  IF NOT public.has_permission(auth.uid(),'retours.refuser_compta') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;
  IF COALESCE(trim(_motif),'')='' THEN RAISE EXCEPTION 'Motif obligatoire'; END IF;
  SELECT * INTO v_retour FROM public.retours WHERE retour_id=_retour_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Retour introuvable'; END IF;
  IF v_retour.version_no <> _version THEN
    RAISE EXCEPTION 'CONFLIT_VERSION' USING ERRCODE='serialization_failure';
  END IF;
  IF v_retour.statut <> 'attente_validation_compta' THEN
    RAISE EXCEPTION 'Statut invalide : %', v_retour.statut;
  END IF;
  UPDATE public.retours SET statut='refus_compta', motif_refus_compta=_motif,
    valide_compta_par=auth.uid(), valide_compta_par_nom=v_user_nom,
    valide_compta_at=now(), version_no=version_no+1, updated_at=now()
  WHERE retour_id=_retour_id;
  UPDATE public.workflow_approvals SET statut='refuse', motif_refus=_motif,
    approbateur_id=auth.uid(), approbateur_nom=v_user_nom, decided_at=now()
  WHERE id=v_retour.workflow_approval_id;
  INSERT INTO public.notifications(titre,message,type_notification,priorite,module,lien,document_type,document_id,document_reference,user_id)
  VALUES ('Retour refusé (comptable)','Motif : '||_motif,'workflow','normal','retours',
          '/retours/'||_retour_id,'retour',_retour_id,
          COALESCE(v_retour.numero,v_retour.reference), v_retour.created_by);
END$$;

CREATE OR REPLACE FUNCTION public.retour_forcer_cloture(_retour_id uuid, _motif text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_retour public.retours; v_user_nom text := public._current_user_display_name();
BEGIN
  IF NOT public.has_permission(auth.uid(),'retours.forcer_cloture') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;
  SELECT * INTO v_retour FROM public.retours WHERE retour_id=_retour_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Retour introuvable'; END IF;
  UPDATE public.retours SET statut='cloture',
    notes=COALESCE(notes,'')||E'\n[Forcé] '||COALESCE(_motif,''),
    version_no=version_no+1, updated_at=now() WHERE retour_id=_retour_id;
  UPDATE public.workflow_approvals SET statut='valide',
    approbateur_id=auth.uid(), approbateur_nom=v_user_nom, decided_at=now()
  WHERE id=v_retour.workflow_approval_id;
END$$;

CREATE OR REPLACE FUNCTION public.approbation_rouvrir(_approval_id uuid, _motif text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NOT public.has_permission(auth.uid(),'approbations.rouvrir') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;
  UPDATE public.workflow_approvals SET statut='en_attente', decided_at=NULL,
    historique = historique || jsonb_build_object('action','rouvrir','par',auth.uid(),'at',now(),'motif',_motif)
  WHERE id=_approval_id;
END$$;

GRANT EXECUTE ON FUNCTION public.retour_creer_demande(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retour_receptionner(uuid,integer,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retour_refuser_magasin(uuid,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retour_simulation_financiere(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retour_valider_compta(uuid,integer,text,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retour_refuser_compta(uuid,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retour_forcer_cloture(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approbation_rouvrir(uuid,text) TO authenticated;
