-- Autoriser les avoirs dans les factures
ALTER TABLE public.factures DROP CONSTRAINT IF EXISTS factures_statut_check;
ALTER TABLE public.factures ADD CONSTRAINT factures_statut_check
  CHECK (statut IN ('brouillon','emise','impayee','partielle','payee','annulee','avoir'));

-- Journal d'audit dédié aux retours
CREATE OR REPLACE FUNCTION public._retour_audit(
  _retour_id uuid, _action text, _details jsonb DEFAULT '{}'::jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.audit_logs(
    user_id, action, table_name, record_id, module, entity_type, entity_id, details, criticite
  ) VALUES (
    auth.uid(), _action, 'retours', _retour_id::text, 'retours', 'retour',
    _retour_id::text, COALESCE(_details,'{}'::jsonb), 'normale'
  );
EXCEPTION WHEN OTHERS THEN NULL;
END; $$;

-- ============================================================
-- Création de la demande de retour
-- ============================================================
CREATE OR REPLACE FUNCTION public.retour_creer_demande(_payload jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_retour_id uuid; v_appr_id uuid;
  v_user_nom text := public._current_user_display_name();
  v_client_id uuid := NULLIF(_payload->>'client_id','')::uuid;
  v_facture_id uuid := NULLIF(_payload->>'facture_id','')::uuid;
  v_livraison_id uuid := NULLIF(_payload->>'livraison_id','')::uuid;
  v_numero text := 'RET-'||to_char(now(),'YYYYMMDD')||'-'||substr(gen_random_uuid()::text,1,6);
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
               WHERE r2.facture_id = v_facture_id AND r2.statut <> 'annule'
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
        RAISE EXCEPTION 'Quantité retournée (%) supérieure à la quantité retournable (%) pour « % »',
          v_qte, v_dispo, COALESCE(v_ligne->>'designation','produit');
      END IF;
    END IF;

    IF COALESCE(v_pu,0) = 0 THEN
      SELECT prix_vente INTO v_pu FROM public.produits WHERE produit_id = v_produit_id;
    END IF;

    INSERT INTO public.retour_lignes (
      retour_id, produit_id, designation, reference_produit,
      quantite, quantite_demandee, prix_unitaire, remise_pct, motif, etat_produit
    ) VALUES (
      v_retour_id, v_produit_id,
      v_ligne->>'designation', v_ligne->>'reference_produit',
      v_qte, v_qte, COALESCE(v_pu,0), COALESCE(v_rem,0),
      NULLIF(v_ligne->>'motif',''),
      COALESCE(NULLIF(v_ligne->>'etat_produit',''),'revendable')
    );
    v_nb := v_nb + 1;
  END LOOP;

  IF v_nb = 0 THEN RAISE EXCEPTION 'Ajoutez au moins une ligne produit'; END IF;

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

  PERFORM public._retour_audit(v_retour_id,'retour.cree',
    jsonb_build_object('numero',v_numero,'client_id',v_client_id,
                       'facture_id',v_facture_id,'lignes',v_nb));

  PERFORM public._notifier_role('gestionnaire_stock','Nouveau retour à réceptionner',
    'Retour '||v_numero,'/retours/'||v_retour_id,'retours','retour',v_retour_id,v_numero);
  PERFORM public._notifier_role('responsable_magasinier','Nouveau retour à réceptionner',
    'Retour '||v_numero,'/retours/'||v_retour_id,'retours','retour',v_retour_id,v_numero);

  RETURN v_retour_id;
END$$;

-- ============================================================
-- Réception magasin — impact stock réel
-- ============================================================
CREATE OR REPLACE FUNCTION public.retour_receptionner(_retour_id uuid, _version integer, _lignes jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_retour public.retours; v_user_nom text := public._current_user_display_name();
  v_ligne jsonb; v_appr_id uuid; v_numero text;
  v_etat text; v_etat_produit text; v_qte numeric; v_produit uuid; v_new_stock numeric;
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
    v_qte  := COALESCE((v_ligne->>'quantite_recue')::numeric,0);
    v_etat := COALESCE(NULLIF(v_ligne->>'etat_reception',''),'conforme');
    v_etat_produit := CASE v_etat
                        WHEN 'conforme'  THEN 'revendable'
                        WHEN 'endommage' THEN 'endommage'
                        ELSE 'perdu' END;

    UPDATE public.retour_lignes SET
      quantite_recue = v_qte,
      etat_reception = v_etat,
      etat_produit   = v_etat_produit,
      commentaire_reception = NULLIF(v_ligne->>'commentaire_reception','')
    WHERE ligne_id = (v_ligne->>'ligne_id')::uuid
    RETURNING produit_id INTO v_produit;

    IF v_produit IS NOT NULL AND v_qte > 0 AND v_retour.depot_id IS NOT NULL THEN
      IF v_etat_produit = 'revendable' THEN
        INSERT INTO public.stocks_depots (produit_id, depot_id, quantite)
        VALUES (v_produit, v_retour.depot_id, v_qte)
        ON CONFLICT (produit_id, depot_id) DO UPDATE
          SET quantite = public.stocks_depots.quantite + EXCLUDED.quantite, updated_at=now();
        SELECT quantite INTO v_new_stock FROM public.stocks_depots
          WHERE produit_id=v_produit AND depot_id=v_retour.depot_id;
        INSERT INTO public.stock_mouvements (
          produit_id, depot_id, type, quantite, quantite_entree, stock_resultant,
          motif, origine, document_id, document_reference, document_table, user_id, user_nom
        ) VALUES (
          v_produit, v_retour.depot_id, 'entree', v_qte, v_qte, v_new_stock,
          'Retour client (revendable)', 'retour', _retour_id, v_numero, 'retours',
          auth.uid(), v_user_nom
        );
      ELSE
        -- Non revendable : tracé en perte, aucune réintégration en stock vendable
        SELECT quantite INTO v_new_stock FROM public.stocks_depots
          WHERE produit_id=v_produit AND depot_id=v_retour.depot_id;
        INSERT INTO public.stock_mouvements (
          produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie,
          stock_resultant, motif, origine, document_id, document_reference,
          document_table, user_id, user_nom, observation
        ) VALUES (
          v_produit, v_retour.depot_id, 'perte', v_qte, 0, 0,
          COALESCE(v_new_stock,0),
          'Retour client ('||v_etat_produit||') — non réintégré', 'retour',
          _retour_id, v_numero, 'retours', auth.uid(), v_user_nom,
          NULLIF(v_ligne->>'commentaire_reception','')
        );
      END IF;
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

  PERFORM public._retour_audit(_retour_id,'retour.receptionne',
    jsonb_build_object('lignes',_lignes,'depot_id',v_retour.depot_id));

  PERFORM public._notifier_role('comptable','Retour à valider financièrement',
    'Retour '||v_numero||' réceptionné','/approbations/'||v_appr_id,
    'retours','retour',_retour_id,v_numero);
END$$;

-- ============================================================
-- Écriture comptable d'un retour (débit ventes / crédit client)
-- ============================================================
CREATE OR REPLACE FUNCTION public.generate_ecriture_retour(_retour_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r RECORD; v_piece text; v_ecriture_id uuid; v_journal uuid; v_ref text;
BEGIN
  SELECT * INTO r FROM public.retours WHERE retour_id=_retour_id;
  IF NOT FOUND OR COALESCE(r.montant,0) = 0 THEN RETURN NULL; END IF;
  v_piece := 'RET:'||r.retour_id::text;
  SELECT ecriture_id INTO v_ecriture_id FROM public.ecritures_comptables WHERE piece_ref=v_piece;
  IF v_ecriture_id IS NOT NULL THEN RETURN v_ecriture_id; END IF;
  v_ref := COALESCE(r.numero, r.reference);
  v_journal := public._journal_id('VTE');
  INSERT INTO public.ecritures_comptables
    (reference, journal_id, journal, date_ecriture, libelle, montant, statut, piece_ref, exercice_id)
  VALUES (v_ref, v_journal, 'VTE', r.date_retour,
    'Retour / avoir '||v_ref||' - '||COALESCE(r.client_nom,r.etablissement,''),
    r.montant, 'valide', v_piece, r.exercice_id)
  RETURNING ecriture_id INTO v_ecriture_id;
  INSERT INTO public.ecriture_lignes (ecriture_id, numero_compte, compte, compte_libelle, libelle, debit, credit) VALUES
    (v_ecriture_id, '701', '701', 'Ventes de marchandises', 'Retour sur vente '||v_ref, r.montant, 0),
    (v_ecriture_id, '411', '411', 'Clients', 'Avoir '||COALESCE(r.client_nom,''), 0, r.montant);
  RETURN v_ecriture_id;
END; $$;

-- ============================================================
-- Validation comptable — impacts financiers réels
-- ============================================================
CREATE OR REPLACE FUNCTION public.retour_valider_compta(
  _retour_id uuid, _version integer, _option text, _montants jsonb, _commentaire text DEFAULT NULL::text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_retour public.retours; v_user_nom text := public._current_user_display_name();
  v_valeur numeric; v_opt text; v_avoir_ref text; v_ecriture uuid;
BEGIN
  IF NOT public.has_permission(auth.uid(),'retours.valider_compta') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;
  v_opt := CASE lower(COALESCE(_option,''))
    WHEN 'solde' THEN 'diminuer_solde'
    WHEN 'avoir' THEN 'creer_avoir'
    WHEN 'remboursement' THEN 'preparer_remboursement'
    WHEN 'aucun' THEN 'aucun_impact'
    ELSE lower(COALESCE(_option,'')) END;
  IF v_opt NOT IN ('diminuer_solde','creer_avoir','preparer_remboursement','aucun_impact') THEN
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
  IF v_retour.exercice_id IS NOT NULL
     AND EXISTS(SELECT 1 FROM public.exercices_comptables
                WHERE exercice_id=v_retour.exercice_id AND statut='cloture') THEN
    RAISE EXCEPTION 'Exercice comptable clôturé';
  END IF;

  v_valeur := COALESCE(NULLIF(_montants->>'valeur_retour','')::numeric, v_retour.montant, 0);
  IF v_valeur <= 0 AND v_opt <> 'aucun_impact' THEN
    RAISE EXCEPTION 'Montant du retour nul : vérifiez les prix unitaires des lignes';
  END IF;

  IF v_opt <> 'aucun_impact' THEN
    -- a) Compte client : la facture d'origine est diminuée, sinon le solde direct
    IF v_retour.facture_id IS NOT NULL THEN
      UPDATE public.factures
         SET montant_total = GREATEST(COALESCE(montant_total,0) - v_valeur, 0), updated_at=now()
       WHERE facture_id = v_retour.facture_id;
      UPDATE public.factures
         SET statut = CASE
              WHEN COALESCE(montant_paye,0) >= montant_total THEN 'payee'
              WHEN COALESCE(montant_paye,0) > 0 THEN 'partielle'
              ELSE 'impayee' END
       WHERE facture_id = v_retour.facture_id AND statut <> 'annulee';
      PERFORM public._recalc_solde_client_internal(v_retour.client_id);
    ELSIF v_retour.client_id IS NOT NULL THEN
      UPDATE public.clients SET solde = COALESCE(solde,0) - v_valeur, updated_at=now()
       WHERE client_id = v_retour.client_id;
    END IF;

    -- b) Avoir client rattaché au document d'origine
    IF NOT EXISTS (SELECT 1 FROM public.factures
                   WHERE notes = 'Avoir sur retour '||COALESCE(v_retour.numero,v_retour.reference)) THEN
      v_avoir_ref := 'AV-'||to_char(now(),'YYYYMMDD')||'-'||substr(gen_random_uuid()::text,1,6);
      INSERT INTO public.factures (
        reference, client_id, client_nom, commande_id, exercice_id,
        date_facture, montant_total, montant_paye, statut, notes
      ) VALUES (
        v_avoir_ref, v_retour.client_id,
        COALESCE(v_retour.client_nom, v_retour.etablissement),
        v_retour.commande_id, v_retour.exercice_id,
        CURRENT_DATE, -v_valeur, 0, 'avoir',
        'Avoir sur retour '||COALESCE(v_retour.numero,v_retour.reference)
      );
    END IF;

    -- c) Écriture comptable
    v_ecriture := public.generate_ecriture_retour(_retour_id);
  END IF;

  UPDATE public.retours SET statut='cloture',
    valide_compta_par=auth.uid(), valide_compta_par_nom=v_user_nom,
    valide_compta_at=now(), version_no=version_no+1, updated_at=now()
  WHERE retour_id=_retour_id;

  UPDATE public.workflow_approvals SET
    statut='valide', approbateur_id=auth.uid(), approbateur_nom=v_user_nom,
    decided_at=now(), commentaire=_commentaire,
    decision_details=jsonb_build_object('option',v_opt,'montants',_montants,'valeur',v_valeur),
    simulation_financiere=_montants
  WHERE id=v_retour.workflow_approval_id;

  PERFORM public._retour_audit(_retour_id,'retour.valide_compta',
    jsonb_build_object('option',v_opt,'valeur',v_valeur,'ecriture_id',v_ecriture,
                       'avoir_reference',v_avoir_ref));

  INSERT INTO public.notifications(titre,message,type_notification,priorite,module,lien,document_type,document_id,document_reference,user_id)
  VALUES ('Retour validé financièrement',
          'Option : '||v_opt||' - Montant : '||v_valeur::text,
          'workflow','normal','retours','/retours/'||_retour_id,
          'retour',_retour_id, COALESCE(v_retour.numero,v_retour.reference), v_retour.created_by);
END$$;