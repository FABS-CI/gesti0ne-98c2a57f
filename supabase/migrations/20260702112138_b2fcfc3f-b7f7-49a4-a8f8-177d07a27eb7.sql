-- Purge TVA historique : aligne les totaux en base sur le HT (TVA supprimée).
UPDATE public.commandes
SET taux_tva = 0,
    montant_tva = 0,
    montant_ttc = COALESCE(total_ht_net, 0) - COALESCE(remise_globale_montant, 0),
    net_a_payer = COALESCE(total_ht_net, 0) - COALESCE(remise_globale_montant, 0),
    montant_total = COALESCE(total_ht_net, 0) - COALESCE(remise_globale_montant, 0)
WHERE COALESCE(taux_tva, 0) <> 0 OR COALESCE(montant_tva, 0) <> 0;