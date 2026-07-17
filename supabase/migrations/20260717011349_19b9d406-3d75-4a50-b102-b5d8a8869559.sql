
-- 1) Recreate enregistrer_approvisionnement (was dropped, causes schema-cache error)
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

  -- Guard: no duplicate product in the same approvisionnement
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
    COALESCE((_payload->>'date_achat')::date, current_date), _payload->>'reference_fournisseur',
    _payload->>'notes', v_qty, v_depot, auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email')
  FROM public.fournisseurs f
  WHERE f.fournisseur_id = (_payload->>'fournisseur_id')::uuid
  RETURNING * INTO a;

  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.achat_lignes(achat_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne)
    VALUES(a.achat_id, NULLIF(l->>'produit_id','')::uuid, l->>'reference_produit', l->>'designation',
      COALESCE((l->>'quantite')::int,0), COALESCE((l->>'prix_unitaire')::numeric,0),
      COALESCE((l->>'quantite')::int,0) * COALESCE((l->>'prix_unitaire')::numeric,0));

    IF l->>'produit_id' IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int,0);
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES((l->>'produit_id')::uuid, v_depot, 0)
      ON CONFLICT (produit_id, depot_id) DO NOTHING;
      SELECT quantite INTO v_actuel FROM public.stocks_depots
        WHERE produit_id = (l->>'produit_id')::uuid AND depot_id = v_depot FOR UPDATE;
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot, v_actuel + v_qte,
        'Approvisionnement ' || a.reference,
        'approvisionnement', a.achat_id, a.reference, 'achats', NULL
      );
    END IF;
  END LOOP;

  RETURN a;
END
$function$;

GRANT EXECUTE ON FUNCTION public.enregistrer_approvisionnement(jsonb) TO authenticated;

-- 2) Prevent duplicate product per parent document via partial unique indexes
CREATE UNIQUE INDEX IF NOT EXISTS achat_lignes_unique_produit_par_achat
  ON public.achat_lignes (achat_id, produit_id) WHERE produit_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS commande_lignes_unique_produit_par_commande
  ON public.commande_lignes (commande_id, produit_id) WHERE produit_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS retour_lignes_unique_produit_par_retour
  ON public.retour_lignes (retour_id, produit_id) WHERE produit_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS colis_lignes_unique_produit_par_colis
  ON public.colis_lignes (colis_id, produit_id) WHERE produit_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS inventaire_lignes_unique_produit_par_inventaire
  ON public.inventaire_lignes (inventaire_id, produit_id) WHERE produit_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS proforma_lignes_unique_produit_par_proforma
  ON public.proforma_lignes (proforma_id, produit_id) WHERE produit_id IS NOT NULL;
