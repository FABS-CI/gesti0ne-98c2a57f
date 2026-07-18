
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT p.produit_id, p.reference, sd.depot_id, sd.quantite AS ancien
    FROM public.produits p
    JOIN public.stocks_depots sd ON sd.produit_id = p.produit_id
    WHERE p.reference IN ('FABS-CI76','FABS-CI79','FABS-CI83')
      AND sd.quantite < 1000
  LOOP
    UPDATE public.stocks_depots
    SET quantite = 1000
    WHERE produit_id = r.produit_id AND depot_id = r.depot_id;

    INSERT INTO public.stock_mouvements(
      produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie,
      stock_resultant, motif, origine, observation
    ) VALUES (
      r.produit_id, r.depot_id, 'ajustement',
      1000 - r.ancien, 1000 - r.ancien, 0, 1000,
      'Rattrapage stock : remise à 1000 (résidu opérations supprimées)',
      'ajustement',
      'Ref '||r.reference||' : '||r.ancien||' → 1000'
    );
  END LOOP;
END $$;
