
-- Journal d'audit : une ligne par produit avec stock non nul
INSERT INTO public.stock_corrections_audit
  (produit_id, stock_avant, stock_apres, ecart, nb_mouvements, motif, corrige_par_nom)
SELECT
  sd.produit_id,
  SUM(sd.quantite)::int AS stock_avant,
  0 AS stock_apres,
  (-SUM(sd.quantite))::int AS ecart,
  0::bigint AS nb_mouvements,
  'Initialisation stocks production - remise a zero globale' AS motif,
  'Systeme (migration production)' AS corrige_par_nom
FROM public.stocks_depots sd
GROUP BY sd.produit_id
HAVING SUM(sd.quantite) <> 0;

-- Remise à zéro des stocks par dépôt (migration en tant que postgres : les triggers readonly ne s'appliquent qu'à authenticated/anon)
UPDATE public.stocks_depots SET quantite = 0 WHERE quantite <> 0;

-- Contrôle
DO $$
DECLARE
  v_nonzero int;
  v_neg int;
BEGIN
  SELECT COUNT(*) INTO v_nonzero FROM public.stocks_depots WHERE quantite <> 0;
  SELECT COUNT(*) INTO v_neg FROM public.stocks_depots WHERE quantite < 0;
  IF v_nonzero > 0 OR v_neg > 0 THEN
    RAISE EXCEPTION 'Initialisation stocks echec: % lignes non nulles, % negatives', v_nonzero, v_neg;
  END IF;
END $$;
