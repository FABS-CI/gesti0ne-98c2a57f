-- 1. recalc_commande: source de vérité unique + propagation vers les documents de vente
CREATE OR REPLACE FUNCTION public.recalc_commande(_commande_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE v record; v_remise_glob numeric; v_ht_net numeric; v_tva numeric; v_total numeric;
BEGIN
  SELECT count(*)::int nb, coalesce(sum(quantite),0)::int qty,
         coalesce(sum(quantite*prix_unitaire),0) brut,
         coalesce(sum(coalesce(montant_remise,0)),0) rem_lignes,
         coalesce(sum(coalesce(total_ht_ligne,total_ligne,quantite*prix_unitaire)),0) ht_lignes
    INTO v
  FROM public.commande_lignes WHERE commande_id=_commande_id;

  -- Remise globale toujours recalculée depuis le %
  SELECT round(coalesce(v.ht_lignes,0) * coalesce(c.remise_globale_pct,0) / 100, 2)
    INTO v_remise_glob
  FROM public.commandes c WHERE c.commande_id=_commande_id;

  v_ht_net := greatest(coalesce(v.ht_lignes,0) - coalesce(v_remise_glob,0), 0);

  UPDATE public.commandes c SET
    nb_produits=coalesce(v.nb,0), total_quantite=coalesce(v.qty,0), total_ht_brut=coalesce(v.brut,0),
    total_remises_lignes=coalesce(v.rem_lignes,0),
    remise_globale_montant=coalesce(v_remise_glob,0),
    total_ht_net=v_ht_net,
    montant_tva=round(v_ht_net*coalesce(c.taux_tva,0)/100,2),
    montant_ttc=round(v_ht_net*(1+coalesce(c.taux_tva,0)/100),2),
    net_a_payer=round(v_ht_net*(1+coalesce(c.taux_tva,0)/100),2),
    montant_total=round(v_ht_net*(1+coalesce(c.taux_tva,0)/100),2),
    updated_at=now()
  WHERE c.commande_id=_commande_id
  RETURNING montant_total INTO v_total;

  -- Propagation : tous les documents de vente s'alignent sur la commande
  UPDATE public.factures SET montant_total=v_total, updated_at=now()
    WHERE commande_id=_commande_id AND montant_total IS DISTINCT FROM v_total;
  UPDATE public.bons_livraison SET montant_total=v_total, updated_at=now()
    WHERE commande_id=_commande_id AND montant_total IS DISTINCT FROM v_total;
  UPDATE public.proformas SET montant_total=v_total, updated_at=now()
    WHERE commande_id=_commande_id AND montant_total IS DISTINCT FROM v_total;
END $function$;

-- 2. Réalignement immédiat des documents existants sur leur commande
UPDATE public.factures f SET montant_total=c.montant_total, updated_at=now()
FROM public.commandes c
WHERE f.commande_id=c.commande_id AND f.montant_total IS DISTINCT FROM c.montant_total;

UPDATE public.bons_livraison b SET montant_total=c.montant_total, updated_at=now()
FROM public.commandes c
WHERE b.commande_id=c.commande_id AND b.montant_total IS DISTINCT FROM c.montant_total;

UPDATE public.proformas p SET montant_total=c.montant_total, updated_at=now()
FROM public.commandes c
WHERE p.commande_id=c.commande_id AND p.montant_total IS DISTINCT FROM c.montant_total;