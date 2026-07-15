
DO $$
DECLARE
  v_bl_id uuid := 'b33cdd59-dea4-4f34-801c-4b1915844885';
  v_cmd_id uuid := '4098ed17-8206-427a-9af8-7b4fab402763';
  v_user_id uuid := '2c55b97c-9cb8-47c1-b7a3-2f9b74114e26';
  v_exercice_id uuid := '08ecfe03-9c73-4366-ad6f-5a39da5903ee';
  v_client_id uuid := 'e15a70f7-7ddc-4e84-81da-86e515e0b259';
  v_c1 uuid; v_c2 uuid; v_cur uuid;
  v_facture_id uuid;
  v_paiement paiements;
  v_bl_final record; v_fac_final record; v_stock_final record; v_liv_final record; v_livsuivi record;
  v_fac_ref text := 'FAC-AUDIT-V2-' || to_char(clock_timestamp(), 'HH24MISSMS');
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user_id::text,'role','authenticated',
      'user_metadata', json_build_object('nom_complet','Audit E2E Prod'),
      'email','audit@e2e.local')::text, true);

  RAISE NOTICE '=== PHASE B — Commande V2 (CMD-20260708-220439) ===';

  DELETE FROM public.colis WHERE bl_id = v_bl_id;

  PERFORM public.creer_colisage(v_bl_id, jsonb_build_object(
    'nb_cartons', 2, 'mode_acheminement', 'livraison',
    'livreur_nom', 'Livreur Audit','livreur_telephone', '0700000000',
    'vehicule', 'CAM-AUDIT','quartier', 'Cocody','commune', 'Abidjan',
    'ville_livraison', 'Abidjan','observations', 'Phase B - colisage V2'
  ));
  SELECT colis_id INTO v_c1 FROM public.colis WHERE bl_id=v_bl_id AND numero_carton=1;
  SELECT colis_id INTO v_c2 FROM public.colis WHERE bl_id=v_bl_id AND numero_carton=2;
  SELECT statut INTO v_bl_final FROM public.bons_livraison WHERE bl_id=v_bl_id;
  RAISE NOTICE 'B1 Colisage OK — 2 colis (%, %), BL statut=%', v_c1, v_c2, v_bl_final.statut;

  SELECT statut::text AS statut, type_livraison::text AS type_livraison, nb_cartons INTO v_livsuivi FROM public.livsuivi_commandes WHERE commande_id=v_cmd_id;
  RAISE NOTICE 'B1 livsuivi_commandes: statut=% type=% nb_cartons=%', v_livsuivi.statut, v_livsuivi.type_livraison, v_livsuivi.nb_cartons;

  FOREACH v_cur IN ARRAY ARRAY[v_c1, v_c2] LOOP
    PERFORM public.changer_statut_colis(v_cur, 'remis_livreur', 'Phase B - remis');
    PERFORM public.changer_statut_colis(v_cur, 'en_cours_livraison', 'Phase B - en route');
    PERFORM public.changer_statut_colis(v_cur, 'arrive_client', 'Phase B - arrivée');
    PERFORM public.changer_statut_colis(v_cur, 'livre', 'Phase B - livré');
  END LOOP;

  SELECT statut, date_livraison INTO v_bl_final FROM public.bons_livraison WHERE bl_id=v_bl_id;
  RAISE NOTICE 'B2 BL après livraison colis: statut=% date_livraison=%', v_bl_final.statut, v_bl_final.date_livraison;

  SELECT statut::text AS statut INTO v_liv_final FROM public.livraisons_commande WHERE commande_id=v_cmd_id;
  RAISE NOTICE 'B2 livraisons_commande: statut=%', v_liv_final.statut;

  INSERT INTO public.factures(reference, client_id, client_nom, commande_id, date_facture, date_echeance, montant_total, montant_paye, statut, notes, exercice_id)
  SELECT v_fac_ref, v_client_id, c.client_nom, v_cmd_id, current_date, current_date + 30,
         c.net_a_payer, 0, 'impayee', 'Phase B - facture V2', v_exercice_id
    FROM public.commandes c WHERE c.commande_id=v_cmd_id
  RETURNING facture_id INTO v_facture_id;
  SELECT statut, montant_paye, montant_total INTO v_fac_final FROM public.factures WHERE facture_id=v_facture_id;
  RAISE NOTICE 'B4 Facture % créée: statut=% montant=%', v_fac_ref, v_fac_final.statut, v_fac_final.montant_total;

  v_paiement := public.enregistrer_paiement(jsonb_build_object(
    'facture_id', v_facture_id,'montant', 20000,
    'mode_paiement', 'especes','observations', 'Phase B - acompte'
  ));
  UPDATE public.paiements SET reference = reference || '-A' WHERE paiement_id = v_paiement.paiement_id;
  SELECT statut, montant_paye, montant_total INTO v_fac_final FROM public.factures WHERE facture_id=v_facture_id;
  RAISE NOTICE 'B5a Acompte 20000 → facture statut=% paye=%/%', v_fac_final.statut, v_fac_final.montant_paye, v_fac_final.montant_total;

  v_paiement := public.enregistrer_paiement(jsonb_build_object(
    'facture_id', v_facture_id,
    'montant', v_fac_final.montant_total - v_fac_final.montant_paye,
    'mode_paiement', 'virement','observations', 'Phase B - solde'
  ));
  UPDATE public.paiements SET reference = reference || '-B' WHERE paiement_id = v_paiement.paiement_id;
  SELECT statut, montant_paye, montant_total INTO v_fac_final FROM public.factures WHERE facture_id=v_facture_id;
  RAISE NOTICE 'B5b Solde → facture statut=% paye=%/%', v_fac_final.statut, v_fac_final.montant_paye, v_fac_final.montant_total;

  RAISE NOTICE '--- Stock dépôt commande (produits concernés) ---';
  FOR v_stock_final IN
    SELECT p.titre AS produit, sd.quantite AS qte
      FROM public.stocks_depots sd
      JOIN public.produits p ON p.produit_id = sd.produit_id
     WHERE sd.depot_id = (SELECT depot_id FROM public.commandes WHERE commande_id=v_cmd_id)
       AND sd.produit_id IN (SELECT produit_id FROM public.commande_lignes WHERE commande_id=v_cmd_id)
     ORDER BY p.titre
  LOOP
    RAISE NOTICE '  % → % en stock', v_stock_final.produit, v_stock_final.qte;
  END LOOP;

  RAISE NOTICE '=== PHASE B TERMINÉE ===';
END $$;
