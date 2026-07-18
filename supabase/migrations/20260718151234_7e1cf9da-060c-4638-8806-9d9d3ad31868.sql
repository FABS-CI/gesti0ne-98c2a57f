
-- 1) Corriger le RPC pour stocker prix_unitaire et total_ligne
CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
 RETURNS SETOF retours
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('RET','public.retours','reference');
  v_num text := v_ref;
  v_l jsonb;
  v_qte_totale numeric := 0;
  v_nb_produits int := 0;
  v_montant numeric := 0;
  v_client_nom text;
  v_created_by_nom text;
  v_commande_id uuid;
  v_client_id uuid := NULLIF(_payload->>'client_id','')::uuid;
  v_facture_id uuid := NULLIF(_payload->>'facture_id','')::uuid;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_type text := COALESCE(NULLIF(_payload->>'type_retour',''), 'physique');
  v_produit uuid;
  v_qte numeric;
  v_prix numeric;
  v_remise numeric;
  v_prix_net numeric;
  v_new_stock numeric;
BEGIN
  PERFORM public.assert_permission('retours.creer');

  IF v_type NOT IN ('physique','avoir') THEN
    RAISE EXCEPTION 'Type de retour invalide: %', v_type;
  END IF;

  IF v_client_id IS NOT NULL THEN
    SELECT nom INTO v_client_nom FROM public.clients WHERE client_id = v_client_id;
  END IF;

  v_created_by_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  IF v_facture_id IS NOT NULL THEN
    SELECT commande_id INTO v_commande_id FROM public.factures WHERE facture_id = v_facture_id;
  END IF;

  IF v_depot IS NULL AND v_type = 'physique' THEN
    SELECT depot_id INTO v_depot FROM public.depots WHERE is_principal=true LIMIT 1;
  END IF;

  INSERT INTO public.retours(
    reference, numero, commande_id, client_id, client_nom, facture_id, livraison_id,
    etablissement, representant_nom, telephone, ville, adresse, depot_id,
    date_retour, statut, motif, notes, observations,
    total_quantite, nb_produits, montant,
    created_by, created_by_nom, type_retour
  ) VALUES (
    v_ref, v_num, v_commande_id, v_client_id,
    COALESCE(_payload->>'client_nom', v_client_nom),
    v_facture_id, NULLIF(_payload->>'livraison_id','')::uuid,
    _payload->>'etablissement', _payload->>'representant_nom', _payload->>'telephone',
    _payload->>'ville', _payload->>'adresse',
    CASE WHEN v_type='physique' THEN v_depot ELSE NULL END,
    COALESCE((_payload->>'date_retour')::date, current_date),
    'accepte', _payload->>'motif', _payload->>'notes', _payload->>'observations',
    0, 0, 0, auth.uid(), v_created_by_nom, v_type
  )
  RETURNING retour_id INTO v_id;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_produit := NULLIF(v_l->>'produit_id','')::uuid;
    v_qte := COALESCE((v_l->>'quantite')::numeric, 0);

    v_prix := NULL;
    v_remise := 0;
    IF v_facture_id IS NOT NULL AND v_produit IS NOT NULL THEN
      SELECT cl.prix_unitaire, COALESCE(cl.remise_pct, 0)
        INTO v_prix, v_remise
      FROM public.factures f
      JOIN public.commande_lignes cl ON cl.commande_id = f.commande_id
      WHERE f.facture_id = v_facture_id AND cl.produit_id = v_produit
      LIMIT 1;
    END IF;
    IF v_prix IS NULL AND v_produit IS NOT NULL THEN
      SELECT prix_vente INTO v_prix FROM public.produits WHERE produit_id = v_produit;
      v_remise := 0;
    END IF;
    v_prix_net := COALESCE(v_prix,0) * (1 - COALESCE(v_remise,0) / 100.0);

    INSERT INTO public.retour_lignes(
      retour_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne, motif
    ) VALUES (
      v_id, v_produit, v_l->>'reference_produit',
      COALESCE(v_l->>'designation',''), v_qte,
      COALESCE(v_prix_net, 0), COALESCE(v_prix_net, 0) * v_qte,
      v_l->>'motif'
    );

    v_qte_totale := v_qte_totale + v_qte;
    v_nb_produits := v_nb_produits + 1;
    v_montant := v_montant + v_prix_net * v_qte;

    IF v_type = 'physique' AND v_produit IS NOT NULL AND v_depot IS NOT NULL AND v_qte > 0 THEN
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES (v_produit, v_depot, v_qte)
      ON CONFLICT (produit_id, depot_id) DO UPDATE
        SET quantite = public.stocks_depots.quantite + EXCLUDED.quantite, updated_at = now();
      SELECT quantite INTO v_new_stock FROM public.stocks_depots
        WHERE produit_id=v_produit AND depot_id=v_depot;
      INSERT INTO public.stock_mouvements(
        produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie,
        stock_resultant, origine, document_id, document_reference, document_table,
        user_id, motif
      ) VALUES (
        v_produit, v_depot, 'entree', v_qte, v_qte, 0, v_new_stock,
        'retour_client', v_id, v_ref, 'retours', auth.uid(),
        COALESCE(v_l->>'motif','Retour client')
      );
    END IF;
  END LOOP;

  UPDATE public.retours
     SET total_quantite = v_qte_totale,
         nb_produits    = v_nb_produits,
         montant        = v_montant
   WHERE retour_id = v_id;

  IF v_montant > 0 AND v_client_id IS NOT NULL THEN
    IF v_facture_id IS NOT NULL THEN
      UPDATE public.factures
         SET montant_total = GREATEST(0, montant_total - v_montant),
             updated_at = now()
       WHERE facture_id = v_facture_id;
      UPDATE public.factures
         SET statut = CASE
           WHEN montant_total <= COALESCE(montant_paye,0) THEN 'payee'
           WHEN COALESCE(montant_paye,0) > 0 THEN 'partielle'
           ELSE statut END
       WHERE facture_id = v_facture_id;
      PERFORM public._recalc_solde_client_internal(v_client_id);
    ELSE
      UPDATE public.clients
         SET solde = GREATEST(0, COALESCE(solde,0) - v_montant),
             updated_at = now()
       WHERE client_id = v_client_id;
    END IF;
  END IF;

  RETURN QUERY SELECT * FROM public.retours WHERE retour_id = v_id;
END;
$function$;

-- 2) Rattrapage rétroactif pour RET-2026-00001
DO $$
DECLARE
  v_retour_id uuid := '1b9dc293-3cce-431c-a425-c8b51c0a021c';
  v_facture_id uuid := '86546b02-3ddb-4362-a292-5959311ca7fb';
  v_client_id uuid := 'b254398b-fd93-4790-aeeb-b541cbd5cef3';
  v_montant numeric;
BEGIN
  -- Recalculer prix_unitaire et total_ligne à partir de commande_lignes
  UPDATE public.retour_lignes rl
     SET prix_unitaire = COALESCE(cl.prix_unitaire, 0) * (1 - COALESCE(cl.remise_pct,0)/100.0),
         total_ligne   = COALESCE(cl.prix_unitaire, 0) * (1 - COALESCE(cl.remise_pct,0)/100.0) * rl.quantite,
         updated_at    = now()
    FROM public.factures f
    JOIN public.commande_lignes cl ON cl.commande_id = f.commande_id
   WHERE rl.retour_id = v_retour_id
     AND f.facture_id = v_facture_id
     AND cl.produit_id = rl.produit_id;

  SELECT COALESCE(SUM(total_ligne),0) INTO v_montant
    FROM public.retour_lignes WHERE retour_id = v_retour_id;

  UPDATE public.retours SET montant = v_montant, updated_at = now() WHERE retour_id = v_retour_id;

  -- Décrémenter la facture (une seule fois — vérifier que ça n'a pas déjà été fait)
  -- La facture est actuellement à 1 772 000 alors que la commande initiale + retour ne l'a jamais réduite.
  UPDATE public.factures
     SET montant_total = GREATEST(0, montant_total - v_montant),
         statut = CASE
           WHEN GREATEST(0, montant_total - v_montant) <= COALESCE(montant_paye,0) THEN 'payee'
           WHEN COALESCE(montant_paye,0) > 0 THEN 'partielle'
           ELSE statut END,
         updated_at = now()
   WHERE facture_id = v_facture_id;

  PERFORM public._recalc_solde_client_internal(v_client_id);
END $$;
