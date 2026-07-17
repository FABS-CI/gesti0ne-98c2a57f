ALTER TABLE public.achats
  ADD COLUMN IF NOT EXISTS exercice_id uuid REFERENCES public.exercices_comptables(exercice_id);

CREATE INDEX IF NOT EXISTS idx_achats_exercice ON public.achats(exercice_id);

-- Backfill par plage de dates
UPDATE public.achats a
SET exercice_id = e.exercice_id
FROM public.exercices_comptables e
WHERE a.exercice_id IS NULL
  AND a.date_achat BETWEEN e.date_debut AND e.date_fin;

-- Fallback : rattacher à l'exercice actif si aucun ne couvre la date
UPDATE public.achats a
SET exercice_id = (
  SELECT exercice_id FROM public.exercices_comptables WHERE statut = 'actif' LIMIT 1
)
WHERE a.exercice_id IS NULL;

-- Régénérer enregistrer_approvisionnement pour renseigner exercice_id
CREATE OR REPLACE FUNCTION public.enregistrer_approvisionnement(_payload jsonb)
 RETURNS achats
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
  v_date date := COALESCE((_payload->>'date_achat')::date, current_date);
  v_qte int;
  v_actuel int;
  v_dup_count int;
  v_exercice uuid;
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

  -- Résolution de l'exercice : couvrant la date, sinon l'exercice actif
  SELECT exercice_id INTO v_exercice
  FROM public.exercices_comptables
  WHERE v_date BETWEEN date_debut AND date_fin
  ORDER BY (statut = 'actif') DESC
  LIMIT 1;

  IF v_exercice IS NULL THEN
    SELECT exercice_id INTO v_exercice
    FROM public.exercices_comptables WHERE statut = 'actif' LIMIT 1;
  END IF;

  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_total := v_total + (COALESCE((l->>'quantite')::int,0) * COALESCE((l->>'prix_unitaire')::numeric,0));
    v_qty := v_qty + COALESCE((l->>'quantite')::int,0);
  END LOOP;

  INSERT INTO public.achats(fournisseur_id, fournisseur_nom, libelle, montant, statut, date_achat,
    reference_fournisseur, notes, total_quantite, depot_id, exercice_id, created_by, created_by_nom)
  SELECT (_payload->>'fournisseur_id')::uuid, f.raison_sociale, 'Approvisionnement', v_total, 'recu',
    v_date,
    _payload->>'reference_fournisseur', _payload->>'notes', v_qty, v_depot, v_exercice, auth.uid(),
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
        (l->>'produit_id')::uuid,
        v_depot,
        (COALESCE(v_actuel,0) + v_qte)::numeric,
        'Approvisionnement ' || a.reference
      );
    END IF;
  END LOOP;

  RETURN a;
END
$function$;