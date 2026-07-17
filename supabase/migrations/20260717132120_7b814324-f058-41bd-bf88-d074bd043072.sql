
CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
 RETURNS SETOF commandes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('CMD', 'public.commandes', 'reference');
  v_ligne jsonb;
  v_tva numeric := COALESCE((_payload->>'taux_tva')::numeric, 0);
  v_remise_g numeric := COALESCE((_payload->>'remise_globale_pct')::numeric, 0);
  v_total_ht_brut numeric := 0;
  v_total_remises numeric := 0;
  v_total_ht_net numeric;
  v_remise_g_mnt numeric;
  v_tva_mnt numeric;
  v_ttc numeric;
  v_nb int := 0;
  v_qte int := 0;
  v_qte_l numeric; v_pu numeric; v_rpct numeric; v_rmnt numeric; v_tot numeric;
  v_can_valider boolean;
  v_statut text;
  v_uid uuid := auth.uid();
  v_pro_id uuid;
  v_pro_ref text;
  v_fac_ref text;
  v_bl_ref text;
  v_ex uuid;
BEGIN
  PERFORM public.assert_permission('commandes.creer');

  v_can_valider := (v_uid IS NOT NULL AND public.has_permission_v2(v_uid, 'commandes.valider'));
  v_statut := CASE WHEN v_can_valider THEN 'validee' ELSE 'en_attente_validation' END;
  v_ex := NULLIF(_payload->>'exercice_id','')::uuid;

  INSERT INTO public.commandes(
    reference, client_id, client_nom, etablissement, representant_nom, telephone, ville, adresse,
    observations, statut, remise_globale_pct, taux_tva, exercice_id, depot_id, created_by
  ) VALUES (
    v_ref,
    NULLIF(_payload->>'client_id','')::uuid,
    _payload->>'client_nom',
    _payload->>'etablissement',
    _payload->>'representant_nom',
    _payload->>'telephone',
    _payload->>'ville',
    _payload->>'adresse',
    _payload->>'observations',
    v_statut,
    v_remise_g, v_tva,
    v_ex,
    NULLIF(_payload->>'depot_id','')::uuid,
    v_uid
  ) RETURNING commande_id INTO v_id;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_qte_l := COALESCE((v_ligne->>'quantite')::numeric, 0);
    v_pu    := COALESCE((v_ligne->>'prix_unitaire')::numeric, 0);
    v_rpct  := COALESCE((v_ligne->>'remise_pct')::numeric, 0);
    v_rmnt  := ROUND(v_qte_l * v_pu * v_rpct / 100, 2);
    v_tot   := ROUND(v_qte_l * v_pu - v_rmnt, 2);
    INSERT INTO public.commande_lignes(
      commande_id, produit_id, reference_produit, designation, quantite, prix_unitaire,
      remise_pct, montant_remise, total_ligne, total_ht_ligne
    ) VALUES (
      v_id,
      NULLIF(v_ligne->>'produit_id','')::uuid,
      v_ligne->>'reference_produit',
      COALESCE(v_ligne->>'designation',''),
      v_qte_l::int, v_pu, v_rpct, v_rmnt, v_tot, v_tot
    );
    v_total_ht_brut := v_total_ht_brut + v_qte_l * v_pu;
    v_total_remises := v_total_remises + v_rmnt;
    v_nb := v_nb + 1;
    v_qte := v_qte + v_qte_l::int;
  END LOOP;

  v_total_ht_net := v_total_ht_brut - v_total_remises;
  v_remise_g_mnt := ROUND(v_total_ht_net * v_remise_g / 100, 2);
  v_total_ht_net := v_total_ht_net - v_remise_g_mnt;
  v_tva_mnt := ROUND(v_total_ht_net * v_tva / 100, 2);
  v_ttc := v_total_ht_net + v_tva_mnt;

  UPDATE public.commandes SET
    nb_produits = v_nb, total_quantite = v_qte,
    total_ht_brut = v_total_ht_brut, total_remises_lignes = v_total_remises,
    total_ht_net = v_total_ht_net, remise_globale_montant = v_remise_g_mnt,
    montant_tva = v_tva_mnt, montant_ttc = v_ttc,
    net_a_payer = v_ttc, montant_total = v_ttc
  WHERE commande_id = v_id;

  -- Proforma automatique dans tous les cas
  v_pro_ref := public._next_ref('PRO', 'public.proformas', 'reference');
  INSERT INTO public.proformas(reference, client_id, client_nom, commande_id, date_proforma, date_validite, montant_total, statut, notes)
  VALUES (v_pro_ref,
          NULLIF(_payload->>'client_id','')::uuid,
          _payload->>'client_nom',
          v_id, current_date, current_date + 30, v_ttc, 'emise',
          'Proforma générée automatiquement depuis '||v_ref)
  RETURNING proforma_id INTO v_pro_id;

  INSERT INTO public.proforma_lignes(proforma_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne)
  SELECT v_pro_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne
  FROM public.commande_lignes WHERE commande_id = v_id;

  -- Si l'utilisateur peut valider : générer facture + BL immédiatement
  IF v_can_valider THEN
    v_fac_ref := public._next_ref('FAC', 'public.factures', 'reference');
    v_bl_ref  := public._next_ref('BL',  'public.bons_livraison', 'reference');

    INSERT INTO public.factures(reference, client_id, client_nom, commande_id, exercice_id, date_facture, date_echeance, montant_total, statut)
    VALUES (v_fac_ref,
            NULLIF(_payload->>'client_id','')::uuid,
            _payload->>'client_nom',
            v_id, v_ex, current_date, current_date + 30, v_ttc, 'impayee');

    INSERT INTO public.bons_livraison(reference, commande_id, client_id, client_nom, date_emission, statut, exercice_id)
    VALUES (v_bl_ref, v_id,
            NULLIF(_payload->>'client_id','')::uuid,
            _payload->>'client_nom',
            current_date, 'a_preparer', v_ex);
  END IF;

  RETURN QUERY SELECT * FROM public.commandes WHERE commande_id = v_id;
END; $function$;
