DO $$
DECLARE
  v_tournee_id uuid; v_livcmd record; v_paiement_id uuid;
  v_facture record; v_client_nom text; v_report text := '';
BEGIN
  SET LOCAL session_replication_role = replica;

  SELECT tournee_id INTO v_tournee_id FROM tournees LIMIT 1;

  INSERT INTO livsuivi_commandes(commande_id, type_livraison, statut, bl_id, tournee_id, nb_cartons, derniere_maj)
  SELECT DISTINCT c.commande_id,
         CASE WHEN c.mode_acheminement='expedition' THEN 'expedition'::livsuivi_type ELSE 'direct'::livsuivi_type END,
         'preparee'::livsuivi_statut, c.bl_id, v_tournee_id,
         count(*) OVER (PARTITION BY c.commande_id), now()
  FROM colis c WHERE c.tournee_id=v_tournee_id AND c.commande_id IS NOT NULL
  ON CONFLICT (commande_id) DO UPDATE SET
    tournee_id=EXCLUDED.tournee_id, statut='preparee'::livsuivi_statut, derniere_maj=now();

  UPDATE tournees SET statut='en_cours', validation_statut='valide', validation_at=now() WHERE tournee_id=v_tournee_id;
  v_report := v_report || E'\n[04] livsuivi_commandes: ' || (SELECT count(*) FROM livsuivi_commandes WHERE tournee_id=v_tournee_id);

  -- 05. Livraison directe : preparee → remise_livreur → depart_depot → arrive_client → livree
  FOR v_livcmd IN SELECT id FROM livsuivi_commandes WHERE tournee_id=v_tournee_id LOOP
    UPDATE livsuivi_commandes SET statut='remise_livreur'::livsuivi_statut, derniere_maj=now() WHERE id=v_livcmd.id;
    UPDATE livsuivi_commandes SET statut='depart_depot'::livsuivi_statut, heure_depart=now(), derniere_maj=now() WHERE id=v_livcmd.id;
    UPDATE livsuivi_commandes SET statut='arrive_client'::livsuivi_statut, heure_arrivee=now(), derniere_maj=now() WHERE id=v_livcmd.id;
    UPDATE livsuivi_commandes SET statut='livree'::livsuivi_statut, heure_livraison=now(),
           receptionnaire_nom='Test E2E', derniere_maj=now() WHERE id=v_livcmd.id;
  END LOOP;

  UPDATE colis SET statut='livre', statut_logistique='livre', date_livraison_reelle=now() WHERE tournee_id=v_tournee_id;
  v_report := v_report || E'\n[05] livrées: ' || (SELECT count(*) FROM livsuivi_commandes WHERE tournee_id=v_tournee_id AND statut='livree');

  -- 06. Paiement
  SELECT * INTO v_facture FROM factures ORDER BY reference LIMIT 1;
  SELECT nom INTO v_client_nom FROM clients WHERE client_id=v_facture.client_id;
  INSERT INTO paiements(paiement_id, facture_id, client_nom, montant, mode_paiement, date_paiement, statut)
  VALUES (gen_random_uuid(), v_facture.facture_id, v_client_nom, v_facture.montant_total, 'especes', now(), 'valide')
  RETURNING paiement_id INTO v_paiement_id;
  UPDATE factures SET montant_paye=montant_total, statut='payee' WHERE facture_id=v_facture.facture_id;
  v_report := v_report || E'\n[06] Paiement ' || (SELECT reference FROM paiements WHERE paiement_id=v_paiement_id)
           || ' → Facture ' || v_facture.reference || ' payée';

  v_report := v_report || E'\n\n=== NOMENCLATURE ===';
  v_report := v_report || E'\nCMD: ' || (SELECT string_agg(reference,', ' ORDER BY reference) FROM commandes);
  v_report := v_report || E'\nBL : ' || (SELECT string_agg(reference,', ' ORDER BY reference) FROM bons_livraison);
  v_report := v_report || E'\nFA : ' || (SELECT string_agg(reference,', ' ORDER BY reference) FROM factures);
  v_report := v_report || E'\nCLI: ' || (SELECT string_agg(reference,', ' ORDER BY reference) FROM colis);
  v_report := v_report || E'\nTRN: ' || (SELECT string_agg(reference,', ' ORDER BY reference) FROM tournees);
  v_report := v_report || E'\nPMT: ' || (SELECT string_agg(reference,', ' ORDER BY reference) FROM paiements);

  RAISE NOTICE '%', v_report;
END $$;