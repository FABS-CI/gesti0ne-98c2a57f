
DO $$
DECLARE
  v_retour_id uuid := '0b34e898-6fe1-4272-8d47-aff13c75db02';
  v_facture_id uuid := '84eb6654-2f98-4031-a287-2c5ee31bdf63';
  v_client_id uuid := '5e23606b-6f96-4f82-b794-bf89bb6a4094';
  v_depot_id uuid := 'ec82130e-aa96-4e90-9164-9e511c9efca2';
  v_ref text := 'RET-2026-00001';
  v_montant numeric := 0;
  r record;
  v_stock_res numeric;
BEGIN
  -- Idempotence : si mouvements déjà créés pour ce retour, on sort.
  IF EXISTS (SELECT 1 FROM stock_mouvements WHERE origine='retour_client' AND document_id = v_retour_id) THEN
    RAISE NOTICE 'Retour déjà rejoué, abort.';
    RETURN;
  END IF;

  -- Assigne le dépôt si manquant
  UPDATE retours SET depot_id = COALESCE(depot_id, v_depot_id) WHERE retour_id = v_retour_id;

  -- Parcourt les lignes, réintègre le stock, cumule le montant
  FOR r IN
    SELECT rl.produit_id, rl.quantite, COALESCE(cl.prix_unitaire, p.prix_vente, 0) AS prix,
           COALESCE(cl.remise_pct, 0) AS remise_pct, rl.designation
    FROM retour_lignes rl
    LEFT JOIN factures f ON f.facture_id = v_facture_id
    LEFT JOIN commande_lignes cl ON cl.commande_id = f.commande_id AND cl.produit_id = rl.produit_id
    LEFT JOIN produits p ON p.produit_id = rl.produit_id
    WHERE rl.retour_id = v_retour_id
  LOOP
    -- Upsert stocks_depots
    INSERT INTO stocks_depots (produit_id, depot_id, quantite)
    VALUES (r.produit_id, v_depot_id, r.quantite)
    ON CONFLICT (produit_id, depot_id) DO UPDATE
      SET quantite = stocks_depots.quantite + EXCLUDED.quantite;

    SELECT quantite INTO v_stock_res FROM stocks_depots WHERE produit_id = r.produit_id AND depot_id = v_depot_id;

    INSERT INTO stock_mouvements (produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie,
                                  stock_resultant, motif, origine, document_id, document_reference, document_table)
    VALUES (r.produit_id, v_depot_id, 'entree', r.quantite, r.quantite, 0,
            COALESCE(v_stock_res, r.quantite), 'Retour client (rejeu)', 'retour_client',
            v_retour_id, v_ref, 'retours');

    v_montant := v_montant + (r.quantite * r.prix * (1 - r.remise_pct / 100.0));
  END LOOP;

  -- Mise à jour du montant du retour
  UPDATE retours SET montant = v_montant, updated_at = now() WHERE retour_id = v_retour_id;

  -- Décrémente la facture liée
  UPDATE factures
    SET montant_total = GREATEST(0, montant_total - v_montant),
        updated_at = now()
    WHERE facture_id = v_facture_id;

  -- Recalcule le statut de la facture
  UPDATE factures
    SET statut = CASE
      WHEN montant_paye >= montant_total THEN 'payee'
      WHEN montant_paye > 0 THEN 'partielle'
      ELSE 'emise'
    END
    WHERE facture_id = v_facture_id;

  -- Recalcule le solde client = somme (factures.montant_total - montant_paye) non annulées
  UPDATE clients c
    SET solde = COALESCE((
      SELECT SUM(f.montant_total - f.montant_paye)
      FROM factures f
      WHERE f.client_id = c.client_id AND f.statut <> 'annulee'
    ), 0),
    updated_at = now()
    WHERE c.client_id = v_client_id;

  RAISE NOTICE 'Retour rejoué : montant=%', v_montant;
END $$;
