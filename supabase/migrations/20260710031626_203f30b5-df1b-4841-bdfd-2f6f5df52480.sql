CREATE OR REPLACE FUNCTION public.creer_inventaire_physique(_payload jsonb)
RETURNS inventaires
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  inv public.inventaires;
  p record;
BEGIN
  INSERT INTO public.inventaires(
    numero, reference, type_inventaire, depot_id, categorie_id,
    date_inventaire, statut, observations, created_by, created_by_nom
  ) VALUES (
    'INV-'||to_char(now(),'YYYYMMDD-HH24MISS'),
    'INV-'||to_char(now(),'YYYYMMDD-HH24MISS'),
    coalesce(_payload->>'type_inventaire','physique'),
    (_payload->>'depot_id')::uuid,
    NULLIF(_payload->>'categorie_id','')::uuid,
    coalesce((_payload->>'date_inventaire')::date, current_date),
    'brouillon',
    _payload->>'observations',
    auth.uid(),
    coalesce(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email')
  ) RETURNING * INTO inv;

  FOR p IN
    SELECT pr.produit_id,
           pr.reference,
           pr.titre,
           coalesce(sd.quantite, 0) AS stock,
           coalesce(pr.prix_achat, 0) AS prix
    FROM public.produits pr
    LEFT JOIN public.stocks_depots sd
      ON sd.produit_id = pr.produit_id
     AND sd.depot_id = inv.depot_id
    WHERE pr.actif
  LOOP
    INSERT INTO public.inventaire_lignes(
      inventaire_id, produit_id, reference_produit, designation,
      stock_theorique, quantite_comptee, ecart, valeur_unitaire, valeur_ecart
    ) VALUES (
      inv.inventaire_id, p.produit_id, p.reference, p.titre,
      p.stock, NULL, 0, p.prix, 0
    );
  END LOOP;

  UPDATE public.inventaires
     SET nb_produits = (SELECT count(*) FROM public.inventaire_lignes WHERE inventaire_id = inv.inventaire_id)
   WHERE inventaire_id = inv.inventaire_id
   RETURNING * INTO inv;

  RETURN inv;
END
$function$;