
-- Lot 1 — Retour lié à un document source

-- 1) Colonne livraison_id
ALTER TABLE public.retours
  ADD COLUMN IF NOT EXISTS livraison_id uuid REFERENCES public.livraisons(livraison_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_retours_livraison_id ON public.retours(livraison_id);

-- 2) Fix calcul_solde_client (colonne montant, statuts corrects)
CREATE OR REPLACE FUNCTION public.calcul_solde_client(_client_id uuid, _exercice_id uuid)
RETURNS numeric
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_report numeric := 0;
  v_factures numeric := 0;
  v_paiements numeric := 0;
  v_retours numeric := 0;
BEGIN
  SELECT COALESCE(SUM(montant), 0) INTO v_report
  FROM public.soldes_ouverture_clients
  WHERE client_id = _client_id AND exercice_id = _exercice_id;

  SELECT COALESCE(SUM(montant_total), 0) INTO v_factures
  FROM public.factures
  WHERE client_id = _client_id
    AND exercice_id = _exercice_id
    AND statut <> 'annulee';

  SELECT COALESCE(SUM(montant), 0) INTO v_paiements
  FROM public.paiements
  WHERE client_id = _client_id
    AND exercice_id = _exercice_id
    AND statut = 'valide';

  SELECT COALESCE(SUM(montant), 0) INTO v_retours
  FROM public.retours
  WHERE client_id = _client_id
    AND exercice_id = _exercice_id
    AND statut IN ('accepte', 'valide');

  RETURN v_report + v_factures - v_paiements - v_retours;
END;
$function$;

-- 3) Fonction get_lignes_retournables pour une facture
CREATE OR REPLACE FUNCTION public.get_lignes_retournables(_facture_id uuid)
RETURNS TABLE(
  produit_id uuid,
  reference_produit text,
  designation text,
  qte_vendue integer,
  qte_deja_retournee integer,
  qte_disponible integer,
  prix_unitaire numeric,
  remise_pct numeric,
  total_ligne numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_commande uuid;
  v_client uuid;
BEGIN
  SELECT f.commande_id, f.client_id INTO v_commande, v_client
  FROM public.factures f WHERE f.facture_id = _facture_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Facture introuvable';
  END IF;
  IF v_commande IS NULL THEN
    RAISE EXCEPTION 'Cette facture n''est pas rattachée à une commande — impossible de charger les lignes';
  END IF;

  RETURN QUERY
  WITH lignes AS (
    SELECT cl.produit_id, cl.reference_produit, cl.designation,
           cl.quantite::int AS qte_vendue,
           cl.prix_unitaire, cl.remise_pct, cl.total_ligne
    FROM public.commande_lignes cl
    WHERE cl.commande_id = v_commande
      AND cl.produit_id IS NOT NULL
  ),
  retournees AS (
    SELECT rl.produit_id, COALESCE(SUM(rl.quantite), 0)::int AS qte_ret
    FROM public.retour_lignes rl
    JOIN public.retours r ON r.retour_id = rl.retour_id
    WHERE r.facture_id = _facture_id
      AND r.statut IN ('accepte', 'valide')
    GROUP BY rl.produit_id
  )
  SELECT l.produit_id, l.reference_produit, l.designation,
         l.qte_vendue,
         COALESCE(r.qte_ret, 0) AS qte_deja_retournee,
         GREATEST(l.qte_vendue - COALESCE(r.qte_ret, 0), 0) AS qte_disponible,
         l.prix_unitaire, l.remise_pct, l.total_ligne
  FROM lignes l
  LEFT JOIN retournees r USING (produit_id)
  ORDER BY l.designation;
END;
$function$;

-- 4) creer_retour v2 : accepte facture_id / livraison_id, valide qtés, calcule montant
CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
RETURNS retours
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  r public.retours;
  l jsonb;
  v_qty int := 0;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_facture uuid := NULLIF(_payload->>'facture_id','')::uuid;
  v_livraison uuid := NULLIF(_payload->>'livraison_id','')::uuid;
  v_client uuid := NULLIF(_payload->>'client_id','')::uuid;
  v_qte int;
  v_actuel int;
  v_montant numeric := 0;
  v_disponible int;
  v_prix numeric;
  v_total numeric;
BEGIN
  IF v_depot IS NULL THEN
    RAISE EXCEPTION 'Le dépôt est obligatoire pour un retour' USING ERRCODE = 'P0001';
  END IF;

  -- Vérifier la cohérence facture <-> client
  IF v_facture IS NOT NULL THEN
    PERFORM 1 FROM public.factures
     WHERE facture_id = v_facture AND (v_client IS NULL OR client_id = v_client);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Facture introuvable ou n''appartient pas à ce client' USING ERRCODE = 'P0002';
    END IF;
  END IF;

  IF v_livraison IS NOT NULL THEN
    PERFORM 1 FROM public.livraisons
     WHERE livraison_id = v_livraison AND (v_client IS NULL OR client_id = v_client);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Livraison introuvable ou n''appartient pas à ce client' USING ERRCODE = 'P0003';
    END IF;
  END IF;

  -- Calcul quantité totale + validation quantités si facture
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_qty := v_qty + COALESCE((l->>'quantite')::int, 0);

    IF v_facture IS NOT NULL AND (l->>'produit_id') IS NOT NULL THEN
      SELECT qte_disponible, prix_unitaire, total_ligne
        INTO v_disponible, v_prix, v_total
      FROM public.get_lignes_retournables(v_facture)
      WHERE produit_id = (l->>'produit_id')::uuid;

      IF v_disponible IS NULL THEN
        RAISE EXCEPTION 'Produit % absent de la facture', l->>'designation'
          USING ERRCODE = 'P0004';
      END IF;
      IF COALESCE((l->>'quantite')::int, 0) > v_disponible THEN
        RAISE EXCEPTION 'Quantité (%): dépasse le disponible (%) pour %',
          l->>'quantite', v_disponible, l->>'designation'
          USING ERRCODE = 'P0005';
      END IF;
      -- prix pondéré au prorata
      v_montant := v_montant + (v_prix * COALESCE((l->>'quantite')::int, 0));
    END IF;
  END LOOP;

  INSERT INTO public.retours(numero, date_retour, client_id, etablissement, representant_nom,
    telephone, ville, adresse, depot_id, observations, notes, statut,
    total_quantite, nb_produits, created_by, created_by_nom,
    facture_id, livraison_id, montant)
  VALUES(
    'RET-' || to_char(now(),'YYYYMMDD-HH24MISS'),
    COALESCE((_payload->>'date_retour')::date, current_date),
    v_client, _payload->>'etablissement', _payload->>'representant_nom',
    _payload->>'telephone', _payload->>'ville', _payload->>'adresse',
    v_depot, _payload->>'observations', _payload->>'notes', 'accepte',
    v_qty,
    jsonb_array_length(COALESCE(_payload->'lignes','[]'::jsonb)),
    auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email'),
    v_facture, v_livraison, v_montant
  )
  RETURNING * INTO r;

  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_prix := 0;
    v_total := 0;
    IF v_facture IS NOT NULL AND (l->>'produit_id') IS NOT NULL THEN
      SELECT prix_unitaire INTO v_prix
      FROM public.get_lignes_retournables(v_facture)
      WHERE produit_id = (l->>'produit_id')::uuid;
      v_total := v_prix * COALESCE((l->>'quantite')::int, 0);
    END IF;

    INSERT INTO public.retour_lignes(retour_id, produit_id, reference_produit,
      designation, quantite, motif, prix_unitaire, total_ligne)
    VALUES(r.retour_id, NULLIF(l->>'produit_id','')::uuid,
      l->>'reference_produit', l->>'designation',
      COALESCE((l->>'quantite')::int, 0), l->>'motif',
      COALESCE(v_prix, 0), COALESCE(v_total, 0));

    IF l->>'produit_id' IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int, 0);
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
        VALUES((l->>'produit_id')::uuid, v_depot, 0)
        ON CONFLICT(produit_id, depot_id) DO NOTHING;
      SELECT quantite INTO v_actuel FROM public.stocks_depots
        WHERE produit_id = (l->>'produit_id')::uuid AND depot_id = v_depot
        FOR UPDATE;
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot, v_actuel + v_qte,
        'Retour ' || r.numero,
        'retour', r.retour_id, r.numero, 'retours', l->>'motif'
      );
    END IF;
  END LOOP;

  RETURN r;
END
$function$;
