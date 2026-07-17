ALTER TABLE public.achats
  ADD COLUMN IF NOT EXISTS fournisseur_nom text,
  ADD COLUMN IF NOT EXISTS total_quantite integer NOT NULL DEFAULT 0;

-- Backfill fournisseur_nom depuis fournisseurs
UPDATE public.achats a
SET fournisseur_nom = f.raison_sociale
FROM public.fournisseurs f
WHERE a.fournisseur_id = f.fournisseur_id
  AND (a.fournisseur_nom IS NULL OR a.fournisseur_nom = '');

-- Backfill total_quantite depuis achat_lignes
UPDATE public.achats a
SET total_quantite = COALESCE(s.q, 0)
FROM (
  SELECT achat_id, SUM(quantite)::int AS q
  FROM public.achat_lignes GROUP BY achat_id
) s
WHERE a.achat_id = s.achat_id;

CREATE OR REPLACE FUNCTION public.enregistrer_approvisionnement(_payload jsonb)
 RETURNS public.achats
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  a public.achats;
  l jsonb;
  v_total numeric := 0;
  v_qty int := 0;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_qte int;
  v_actuel int;
  v_dup_count int;
BEGIN
  IF v_depot IS NULL THEN
    RAISE EXCEPTION 'Le dépôt est obligatoire pour un approvisionnement';
  END IF;

  SELECT COUNT(*) INTO v_dup_count FROM (
    SELECT (x->>'produit_id')::uuid AS pid
    FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) x
    WHERE NULLIF(x->>'produit_id','') IS NOT NULL
    GROUP BY (x->>'produit_id')::uuid
    HAVING COUNT(*) > 1
  ) d;
  IF v_dup_count > 0 THEN
    RAISE EXCEPTION 'Un même produit ne peut pas être ajouté plusieurs fois dans un approvisionnement';
  END IF;

  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_total := v_total + (COALESCE((l->>'quantite')::int,0) * COALESCE((l->>'prix_unitaire')::numeric,0));
    v_qty := v_qty + COALESCE((l->>'quantite')::int,0);
  END LOOP;

  INSERT INTO public.achats(fournisseur_id, fournisseur_nom, libelle, montant, statut, date_achat,
    reference_fournisseur, notes, total_quantite, depot_id, created_by, created_by_nom)
  SELECT (_payload->>'fournisseur_id')::uuid, f.raison_sociale, 'Approvisionnement', v_total, 'recu',
    COALESCE((_payload->>'date_achat')::date, current_date),
    _payload->>'reference_fournisseur', _payload->>'notes', v_qty, v_depot, auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email')
  FROM public.fournisseurs f
  WHERE f.fournisseur_id = (_payload->>'fournisseur_id')::uuid
  RETURNING * INTO a;

  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.achat_lignes(achat_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne)
    VALUES(a.achat_id, NULLIF(l->>'produit_id','')::uuid, l->>'reference_produit', l->>'designation',
      COALESCE((l->>'quantite')::int,0), COALESCE((l->>'prix_unitaire')::numeric,0),
      COALESCE((l->>'quantite')::int,0) * COALESCE((l->>'prix_unitaire')::numeric,0));

    IF NULLIF(l->>'produit_id','') IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int,0);
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES((l->>'produit_id')::uuid, v_depot, 0)
      ON CONFLICT (produit_id, depot_id) DO NOTHING;
      SELECT quantite INTO v_actuel FROM public.stocks_depots
        WHERE produit_id = (l->>'produit_id')::uuid AND depot_id = v_depot FOR UPDATE;
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot, COALESCE(v_actuel,0) + v_qte,
        'Approvisionnement ' || a.reference,
        'approvisionnement', a.achat_id, a.reference, 'achats', NULL
      );
    END IF;
  END LOOP;

  RETURN a;
END
$function$;

GRANT EXECUTE ON FUNCTION public.enregistrer_approvisionnement(jsonb) TO authenticated;