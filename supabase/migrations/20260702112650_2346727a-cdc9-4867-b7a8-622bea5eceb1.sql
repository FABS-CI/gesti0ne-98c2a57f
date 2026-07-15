UPDATE public.factures f
SET montant_total = GREATEST(COALESCE(c.total_ht_net, 0) - COALESCE(c.remise_globale_montant, 0), 0)
FROM public.commandes c
WHERE f.commande_id = c.commande_id
  AND f.montant_total <> GREATEST(COALESCE(c.total_ht_net, 0) - COALESCE(c.remise_globale_montant, 0), 0);