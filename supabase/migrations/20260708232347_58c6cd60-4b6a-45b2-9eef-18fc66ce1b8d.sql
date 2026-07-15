
-- A10: Fix trg_notif_livraisons — table livraisons_commande PK is livraison_id, not id.
CREATE OR REPLACE FUNCTION public.trg_notif_livraisons()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE v_ref text;
BEGIN
  IF TG_OP='UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut THEN
    SELECT reference INTO v_ref FROM public.commandes WHERE commande_id = NEW.commande_id;
    IF NEW.statut::text = 'en_cours_livraison' OR NEW.statut::text='expediee' THEN
      PERFORM public.creer_notification('Depart en livraison - '||COALESCE(v_ref,''),
        'La livraison est en cours','info','livraisons','livraisons_commande',NEW.livraison_id, v_ref,
        '/suivi-livraison','service_logistique',NULL,'normale');
    ELSIF NEW.statut::text IN ('livree','livraison_confirmee','retiree_client') THEN
      PERFORM public.creer_notification('Livraison effectuee - '||COALESCE(v_ref,''),
        'Livraison terminee','succes','livraisons','livraisons_commande',NEW.livraison_id, v_ref,
        '/suivi-livraison','directeur_commercial',NULL,'normale');
      PERFORM public.creer_notification('Livraison effectuee - '||COALESCE(v_ref,''),
        'Livraison terminee','succes','livraisons','livraisons_commande',NEW.livraison_id, v_ref,
        '/suivi-livraison','service_logistique',NULL,'normale');
    ELSIF NEW.statut::text='anomalie' THEN
      PERFORM public.creer_notification('Incident livraison - '||COALESCE(v_ref,''),
        COALESCE(NEW.anomalie_motif,'Incident signale'),'erreur','livraisons','livraisons_commande',
        NEW.livraison_id, v_ref,'/suivi-livraison','service_logistique',NULL,'haute');
    END IF;
  END IF;
  RETURN NEW;
END $function$;

-- Test Phase B V3
DO $$
DECLARE
  v_user_id uuid := '2c55b97c-9cb8-47c1-b7a3-2f9b74114e26';
  v_exercice_id uuid := '08ecfe03-9c73-4366-ad6f-5a39da5903ee';
  v_client_id uuid := '14cc8fd8-81ea-4c22-a47a-34c4f253646f';
  v_client_nom text;
  v_depot_id uuid := 'c96741d5-3efb-4001-a067-ae419213f1c6';
  v_produit_id uuid := '15e5b8bc-cb83-44ad-bae6-92738ffabe43';
  v_produit_titre text;
  v_prix numeric := 3000;
  v_qte int := 4;
  v_cmd_id uuid;
  v_cmd_ref text;
  v_bl_id uuid;
  v_bl_ref text;
  v_bl record;
  v_c1 uuid; v_c2 uuid; v_cur uuid;
  v_facture public.factures;
  v_facture2 public.factures;
  v_paiement public.paiements;
  v_fac record;
  v_cmd record;
  v_liv record;
  v_livsuivi record;
  v_stock_before int;
  v_stock_after int;
  r record;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user_id::text,'role','authenticated',
      'user_metadata', json_build_object('nom_complet','Audit Phase B V3'),
      'email','audit-v3@e2e.local')::text, true);

  SELECT nom INTO v_client_nom FROM public.clients WHERE client_id=v_client_id;
  SELECT titre INTO v_produit_titre FROM public.produits WHERE produit_id=v_produit_id;
  SELECT quantite INTO v_stock_before FROM public.stocks_depots
    WHERE depot_id=v_depot_id AND produit_id=v_produit_id;

  RAISE NOTICE '=== PHASE B V3 - Verification synchro statuts ===';
  RAISE NOTICE 'Stock initial produit: %', v_stock_before;

  INSERT INTO public.commandes(client_id, client_nom, statut, depot_id, exercice_id,
    montant_total, montant_ttc, net_a_payer, total_ht_brut, total_ht_net,
    nb_produits, total_quantite, notes)
  VALUES (v_client_id, v_client_nom, 'brouillon', v_depot_id, v_exercice_id,
    v_prix*v_qte, v_prix*v_qte, v_prix*v_qte, v_prix*v_qte, v_prix*v_qte,
    1, v_qte, 'Phase B V3')
  RETURNING commande_id, reference INTO v_cmd_id, v_cmd_ref;

  INSERT INTO public.commande_lignes(commande_id, produit_id, designation, quantite,
    prix_unitaire, total_ligne, total_ht_ligne, reference_produit)
  VALUES (v_cmd_id, v_produit_id, v_produit_titre, v_qte, v_prix,
    v_prix*v_qte, v_prix*v_qte, 'PROD-V3');

  RAISE NOTICE 'B0 Commande: % (%)', v_cmd_ref, v_cmd_id;

  PERFORM public.valider_commande(v_cmd_id);
  SELECT statut INTO v_cmd FROM public.commandes WHERE commande_id=v_cmd_id;
  SELECT quantite INTO v_stock_after FROM public.stocks_depots
    WHERE depot_id=v_depot_id AND produit_id=v_produit_id;
  RAISE NOTICE 'B1 valider -> statut=% | stock % -> % (delta=%)',
    v_cmd.statut, v_stock_before, v_stock_after, v_stock_before - v_stock_after;

  SELECT bl_id, reference INTO v_bl_id, v_bl_ref
    FROM public.convertir_commande_en_bl(v_cmd_id, 2, 5.0, 'Livraison directe',
      'Cocody Abidjan', 'Audit V3', current_date, false);
  SELECT statut, date_livraison INTO v_bl FROM public.bons_livraison WHERE bl_id=v_bl_id;
  SELECT statut INTO v_cmd FROM public.commandes WHERE commande_id=v_cmd_id;
  RAISE NOTICE 'B2 BL % statut=% | commande statut=%', v_bl_ref, v_bl.statut, v_cmd.statut;

  PERFORM public.creer_colisage(v_bl_id, jsonb_build_object(
    'nb_cartons', 2, 'mode_acheminement', 'livraison',
    'livreur_nom', 'Livreur V3','livreur_telephone', '0700000003',
    'vehicule', 'CAM-V3','quartier', 'Cocody','commune', 'Abidjan',
    'ville_livraison', 'Abidjan','observations', 'Phase B V3'
  ));
  SELECT colis_id INTO v_c1 FROM public.colis WHERE bl_id=v_bl_id AND numero_carton=1;
  SELECT colis_id INTO v_c2 FROM public.colis WHERE bl_id=v_bl_id AND numero_carton=2;
  SELECT statut::text AS statut, type_livraison::text AS type_livraison, nb_cartons
    INTO v_livsuivi FROM public.livsuivi_commandes WHERE commande_id=v_cmd_id;
  RAISE NOTICE 'B3 Colisage: c1=% c2=% | livsuivi statut=% type=% nb=%',
    v_c1, v_c2, v_livsuivi.statut, v_livsuivi.type_livraison, v_livsuivi.nb_cartons;

  FOREACH v_cur IN ARRAY ARRAY[v_c1, v_c2] LOOP
    PERFORM public.changer_statut_colis(v_cur, 'remis_livreur', 'V3');
    PERFORM public.changer_statut_colis(v_cur, 'en_cours_livraison', 'V3');
    PERFORM public.changer_statut_colis(v_cur, 'arrive_client', 'V3');
    PERFORM public.changer_statut_colis(v_cur, 'livre', 'V3');
  END LOOP;

  RAISE NOTICE '--- Post-livraison ---';
  FOR r IN SELECT numero_carton, statut::text AS s, statut_logistique::text AS sl
             FROM public.colis WHERE bl_id=v_bl_id ORDER BY numero_carton
  LOOP
    RAISE NOTICE '  Colis #%: statut=% sl=%', r.numero_carton, r.s, r.sl;
  END LOOP;

  SELECT statut, date_livraison INTO v_bl FROM public.bons_livraison WHERE bl_id=v_bl_id;
  RAISE NOTICE 'B4 BL: statut=% (attendu=livre) date=%', v_bl.statut, v_bl.date_livraison;

  SELECT statut INTO v_cmd FROM public.commandes WHERE commande_id=v_cmd_id;
  RAISE NOTICE 'B4 commande: statut=% (attendu=livree)', v_cmd.statut;

  SELECT statut::text AS statut, cloturee INTO v_livsuivi
    FROM public.livsuivi_commandes WHERE commande_id=v_cmd_id;
  RAISE NOTICE 'B4 livsuivi: statut=% cloturee=% (attendu=livree/true)',
    v_livsuivi.statut, v_livsuivi.cloturee;

  SELECT statut::text AS statut INTO v_liv
    FROM public.livraisons_commande WHERE commande_id=v_cmd_id;
  RAISE NOTICE 'B4 livraisons_commande: statut=% (attendu=livree)', v_liv.statut;

  v_facture := public.generer_facture(v_cmd_id);
  RAISE NOTICE 'B5 facture: % statut=% total=%',
    v_facture.reference, v_facture.statut, v_facture.montant_total;

  v_facture2 := public.generer_facture(v_cmd_id);
  IF v_facture2.facture_id = v_facture.facture_id THEN
    RAISE NOTICE 'B5bis idempotent OK';
  ELSE
    RAISE WARNING 'B5bis NON idempotent';
  END IF;

  v_paiement := public.enregistrer_paiement(jsonb_build_object(
    'facture_id', v_facture.facture_id,'montant', v_facture.montant_total,
    'mode_paiement', 'especes','observations', 'Phase B V3 solde'
  ));
  SELECT statut, montant_paye, montant_total INTO v_fac
    FROM public.factures WHERE facture_id=v_facture.facture_id;
  RAISE NOTICE 'B6 Paiement -> facture statut=% paye=%/%',
    v_fac.statut, v_fac.montant_paye, v_fac.montant_total;

  RAISE NOTICE '=== BILAN V3 - Commande: % ===', v_cmd_ref;
END $$;
