DO $$
DECLARE
    v_commande_id uuid := 'c5e7c22c-37ce-4a17-84b8-b3a00f7e42bc';
    v_facture_id uuid := '542821be-2009-4104-b74d-717893b4654a';
    v_depot_id uuid;
    v_ligne record;
BEGIN
    -- Récupérer le dépôt depuis la commande
    SELECT depot_id INTO v_depot_id FROM public.commandes WHERE commande_id = v_commande_id;

    -- 1. Restaurer les stocks (On remet ce qui a été sorti)
    FOR v_ligne IN SELECT produit_id, quantite FROM public.commande_lignes WHERE commande_id = v_commande_id LOOP
        UPDATE public.stocks_depots 
        SET quantite = quantite + v_ligne.quantite
        WHERE produit_id = v_ligne.produit_id AND depot_id = v_depot_id;
    END LOOP;

    -- 2. Supprimer les impacts logistiques
    DELETE FROM public.colis_lignes WHERE colis_id IN (SELECT colis_id FROM public.colis WHERE commande_id = v_commande_id);
    DELETE FROM public.colis WHERE commande_id = v_commande_id;
    DELETE FROM public.bons_livraison WHERE commande_id = v_commande_id;
    DELETE FROM public.stock_mouvements WHERE document_id = v_commande_id OR document_reference = 'FAC-2026-00008';

    -- 3. Supprimer les impacts financiers
    DELETE FROM public.ecritures_comptables WHERE libelle ILIKE '%FAC-2026-00008%' OR libelle ILIKE '%CMD-2026-00008%';
    DELETE FROM public.paiements WHERE facture_id = v_facture_id;

    -- 4. Supprimer la facture (puisqu'elle n'aurait pas dû exister sans validation)
    DELETE FROM public.factures WHERE facture_id = v_facture_id;

    -- 5. Remettre la commande en statut 'en_attente_validation' (statut valide du CHECK constraint)
    UPDATE public.commandes SET statut = 'en_attente_validation' WHERE commande_id = v_commande_id;

END $$;