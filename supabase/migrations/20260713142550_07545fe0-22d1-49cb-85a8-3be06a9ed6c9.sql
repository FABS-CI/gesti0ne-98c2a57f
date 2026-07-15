DO $$
DECLARE
  v_ids uuid[];
BEGIN
  SELECT array_agg(produit_id) INTO v_ids
  FROM public.produits
  WHERE reference IN ('REF-2e8ab95b','REF-b65f66dd','REF-41f9c34f','REF-46af4021','REF-81db1e64')
    AND titre LIKE 'P-%';

  IF v_ids IS NULL OR array_length(v_ids, 1) = 0 THEN
    RETURN;
  END IF;

  DELETE FROM public.stock_mouvements WHERE produit_id = ANY(v_ids);
  DELETE FROM public.stocks_depots WHERE produit_id = ANY(v_ids);
  DELETE FROM public.commande_lignes WHERE produit_id = ANY(v_ids);
  DELETE FROM public.proforma_lignes WHERE produit_id = ANY(v_ids);
  DELETE FROM public.colis_lignes WHERE produit_id = ANY(v_ids);
  DELETE FROM public.specimen_lignes WHERE produit_id = ANY(v_ids);
  DELETE FROM public.retour_lignes WHERE produit_id = ANY(v_ids);
  DELETE FROM public.incident_lignes WHERE produit_id = ANY(v_ids);
  DELETE FROM public.achat_lignes WHERE produit_id = ANY(v_ids);
  DELETE FROM public.transfert_lignes WHERE produit_id = ANY(v_ids);
  DELETE FROM public.inventaire_lignes WHERE produit_id = ANY(v_ids);
  DELETE FROM public.produits WHERE produit_id = ANY(v_ids);
END $$;