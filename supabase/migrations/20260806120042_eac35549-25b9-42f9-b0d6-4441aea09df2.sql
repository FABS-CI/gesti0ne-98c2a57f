-- Amélioration du module Retour : Comptabilité et Robustesse

CREATE OR REPLACE FUNCTION public.generate_ecriture_retour(_retour_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_retour RECORD;
  v_piece text;
  v_ecriture_id uuid;
  v_journal uuid;
  v_montant numeric;
BEGIN
  SELECT * INTO v_retour FROM public.retours WHERE retour_id = _retour_id;
  IF NOT FOUND OR v_retour.statut <> 'cloture' OR COALESCE(v_retour.montant, 0) <= 0 THEN
    RETURN NULL;
  END IF;

  v_piece := 'RET:' || v_retour.retour_id::text;
  
  -- Évite les doublons
  SELECT ecriture_id INTO v_ecriture_id FROM public.ecritures_comptables WHERE piece_ref = v_piece;
  IF v_ecriture_id IS NOT NULL THEN RETURN v_ecriture_id; END IF;

  v_journal := public._journal_id('OD'); -- Opérations Diverses ou Ventes ? On utilise OD pour les retours sans facture d'avoir
  v_montant := v_retour.montant;

  INSERT INTO public.ecritures_comptables
    (reference, journal_id, journal, date_ecriture, libelle, montant, statut, piece_ref, exercice_id)
  VALUES (COALESCE(v_retour.numero, v_retour.reference), v_journal, 'OD', CURRENT_DATE,
     'Retour ' || COALESCE(v_retour.numero, v_retour.reference) || ' - ' || COALESCE(v_retour.client_nom,''),
     v_montant, 'valide', v_piece, v_retour.exercice_id)
  RETURNING ecriture_id INTO v_ecriture_id;

  -- Écriture de retour : On débite le compte de produit (701) et on crédite le client (411)
  -- C'est l'inverse d'une facture.
  INSERT INTO public.ecriture_lignes (ecriture_id, numero_compte, compte, compte_libelle, libelle, debit, credit) VALUES
    (v_ecriture_id, '701', '701', 'Ventes de marchandises', 'Annulation vente retour ' || COALESCE(v_retour.numero, v_retour.reference), v_montant, 0),
    (v_ecriture_id, '411', '411', 'Clients',                'Crédit client retour ' || COALESCE(v_retour.numero, v_retour.reference), 0, v_montant);

  RETURN v_ecriture_id;
END; $$;

CREATE OR REPLACE FUNCTION public.retour_valider_compta(
  _retour_id uuid, _version integer, _option text, _montants jsonb, _commentaire text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_retour public.retours; v_user_nom text := public._current_user_display_name();
  v_valeur numeric := COALESCE((_montants->>'valeur_retour')::numeric, COALESCE((_montants->>'montant_total')::numeric, 0));
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

  -- Si l'option est de diminuer le solde, on le fait et on génère une écriture OD
  IF _option='diminuer_solde' AND v_retour.client_id IS NOT NULL THEN
    UPDATE public.clients SET solde=COALESCE(solde,0)-v_valeur, updated_at=now()
    WHERE client_id=v_retour.client_id;
  END IF;

  -- Si on crée un avoir, le trigger de la facture d'avoir s'occupera de l'écriture compta (VT)
  IF _option='creer_avoir' AND v_retour.client_id IS NOT NULL THEN
    INSERT INTO public.factures (
      reference, client_id, client_nom, commande_id, exercice_id,
      date_facture, montant_total, statut, notes, type_facture
    ) VALUES (
      'AV-'||to_char(now(),'YYYYMMDD')||'-'||substr(gen_random_uuid()::text,1,6),
      v_retour.client_id, v_retour.client_nom, v_retour.commande_id, v_retour.exercice_id,
      CURRENT_DATE, -v_valeur, 'avoir',
      'Avoir sur retour '||COALESCE(v_retour.numero,v_retour.reference),
      'avoir'
    );
  END IF;

  UPDATE public.retours SET statut='cloture',
    valide_compta_par=auth.uid(), valide_compta_par_nom=v_user_nom,
    valide_compta_at=now(), version_no=version_no+1, updated_at=now(),
    montant = v_valeur -- On s'assure que le montant final est stocké
  WHERE retour_id=_retour_id;

  -- Génération de l'écriture comptable pour l'option 'diminuer_solde'
  IF _option = 'diminuer_solde' THEN
    PERFORM public.generate_ecriture_retour(_retour_id);
  END IF;

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
END; $$;
