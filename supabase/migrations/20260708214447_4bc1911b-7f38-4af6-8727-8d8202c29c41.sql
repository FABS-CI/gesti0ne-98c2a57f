DO $$
DECLARE
  v_produit uuid := 'f8572bf4-4da3-430f-874f-98972a1f9d17';
  v_depot   uuid := 'c96741d5-3efb-4001-a067-ae419213f1c6';
  v_avant   int;
  v_apres   int;
BEGIN
  SELECT quantite INTO v_avant FROM public.stocks_depots
   WHERE produit_id = v_produit AND depot_id = v_depot FOR UPDATE;

  v_apres := v_avant + 200;

  UPDATE public.stocks_depots
     SET quantite = v_apres, updated_at = now()
   WHERE produit_id = v_produit AND depot_id = v_depot;

  INSERT INTO public.stock_mouvements(
    produit_id, depot_id, type, quantite,
    quantite_entree, quantite_sortie, stock_resultant,
    motif, observation, origine, user_nom
  ) VALUES (
    v_produit, v_depot, 'ajustement', 200,
    200, 0, v_apres,
    'Régularisation écart stocks_depots ↔ historique',
    'Audit final production : écart de -200 sur FABS-CI79. Alignement de stocks_depots sur l''historique des mouvements.',
    'ajustement_audit', 'system:audit-prod'
  );

  INSERT INTO public.stock_corrections_audit(
    produit_id, stock_avant, stock_apres, ecart, nb_mouvements, motif, corrige_par_nom
  ) VALUES (
    v_produit, v_avant, v_apres, 200, 1,
    'Régularisation audit final production (dépôt principal)', 'system:audit-prod'
  );
END $$;