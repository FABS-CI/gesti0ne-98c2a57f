
CREATE OR REPLACE FUNCTION public.rapport_apply_filters(_filtres jsonb)
RETURNS TABLE (
  ligne_id uuid, commande_id uuid, commande_reference text, commande_statut text,
  date_commande date, facture_id uuid, depot_id uuid, client_id uuid, client_nom text,
  type_client text, representant text, client_ville text, client_quartier text,
  client_pays text, client_categorie text, produit_id uuid, produit_code text,
  produit_titre text, niveau text, produit_categorie text, prix_vente numeric,
  quantite integer, prix_unitaire numeric, remise_pct numeric, montant_remise numeric,
  total_ligne numeric
) LANGUAGE sql STABLE SET search_path='public' AS $$
  SELECT v.*
  FROM public.v_ventes_produits v
  WHERE
    (NULLIF(_filtres->>'from','') IS NULL OR v.date_commande >= (_filtres->>'from')::date)
    AND (NULLIF(_filtres->>'to','') IS NULL OR v.date_commande <= (_filtres->>'to')::date)
    AND (_filtres->'niveaux'      IS NULL OR jsonb_array_length(_filtres->'niveaux')=0      OR v.niveau            = ANY(SELECT jsonb_array_elements_text(_filtres->'niveaux')))
    AND (_filtres->'categories'   IS NULL OR jsonb_array_length(_filtres->'categories')=0   OR v.produit_categorie = ANY(SELECT jsonb_array_elements_text(_filtres->'categories')))
    AND (_filtres->'types'        IS NULL OR jsonb_array_length(_filtres->'types')=0        OR v.type_client       = ANY(SELECT jsonb_array_elements_text(_filtres->'types')))
    AND (_filtres->'villes'       IS NULL OR jsonb_array_length(_filtres->'villes')=0       OR v.client_ville      = ANY(SELECT jsonb_array_elements_text(_filtres->'villes')))
    AND (_filtres->'representants' IS NULL OR jsonb_array_length(_filtres->'representants')=0 OR v.representant     = ANY(SELECT jsonb_array_elements_text(_filtres->'representants')))
    AND (_filtres->'statuts'      IS NULL OR jsonb_array_length(_filtres->'statuts')=0      OR v.commande_statut   = ANY(SELECT jsonb_array_elements_text(_filtres->'statuts')))
    AND (_filtres->'produits'     IS NULL OR jsonb_array_length(_filtres->'produits')=0     OR v.produit_id::text  = ANY(SELECT jsonb_array_elements_text(_filtres->'produits')))
    AND (NULLIF(_filtres->>'client_id','') IS NULL OR v.client_id = (_filtres->>'client_id')::uuid);
$$;

GRANT EXECUTE ON FUNCTION public.rapport_apply_filters(jsonb) TO authenticated, anon, service_role;

CREATE OR REPLACE FUNCTION public.rapport_kpi(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='public' AS $$
DECLARE _res jsonb;
BEGIN
  WITH b AS (SELECT * FROM public.rapport_apply_filters(_filtres)),
  glob AS (
    SELECT COALESCE(SUM(quantite),0) AS qte_vendue,
      COALESCE(SUM(CASE WHEN facture_id IS NOT NULL THEN quantite END),0) AS qte_facturee,
      COUNT(DISTINCT facture_id) FILTER (WHERE facture_id IS NOT NULL) AS nb_factures,
      COUNT(DISTINCT client_id) AS nb_clients,
      COALESCE(SUM(total_ligne),0) AS ca,
      COUNT(DISTINCT commande_id) AS nb_commandes
    FROM b
  ),
  top1  AS (SELECT produit_titre FROM b WHERE produit_id IS NOT NULL GROUP BY produit_titre ORDER BY SUM(quantite) DESC LIMIT 1),
  rent1 AS (SELECT produit_titre FROM b WHERE produit_id IS NOT NULL GROUP BY produit_titre ORDER BY SUM(total_ligne) DESC LIMIT 1),
  flop1 AS (SELECT produit_titre FROM b WHERE produit_id IS NOT NULL GROUP BY produit_titre ORDER BY SUM(quantite) ASC LIMIT 1)
  SELECT jsonb_build_object(
    'qte_vendue',(SELECT qte_vendue FROM glob),
    'qte_facturee',(SELECT qte_facturee FROM glob),
    'nb_factures',(SELECT nb_factures FROM glob),
    'nb_clients',(SELECT nb_clients FROM glob),
    'ca',(SELECT ca FROM glob),
    'nb_commandes',(SELECT nb_commandes FROM glob),
    'prix_moyen', CASE WHEN (SELECT qte_vendue FROM glob)>0 THEN ROUND((SELECT ca FROM glob)/(SELECT qte_vendue FROM glob),2) ELSE 0 END,
    'panier_moyen', CASE WHEN (SELECT nb_factures FROM glob)>0 THEN ROUND((SELECT ca FROM glob)/(SELECT nb_factures FROM glob),2) ELSE 0 END,
    'top_produit',(SELECT produit_titre FROM top1),
    'rentable_produit',(SELECT produit_titre FROM rent1),
    'flop_produit',(SELECT produit_titre FROM flop1)
  ) INTO _res;
  RETURN _res;
END; $$;

CREATE OR REPLACE FUNCTION public.rapport_top_produits(_filtres jsonb DEFAULT '{}'::jsonb, _limit int DEFAULT 20)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='public' AS $$
  SELECT COALESCE(jsonb_agg(t ORDER BY t.qte_vendue DESC), '[]'::jsonb) FROM (
    SELECT b.produit_id, b.produit_code AS code, b.produit_titre AS titre, b.niveau,
           b.produit_categorie AS categorie,
           SUM(b.quantite)::int AS qte_vendue,
           SUM(b.total_ligne)   AS ca,
           COUNT(DISTINCT b.client_id)  AS nb_clients,
           COUNT(DISTINCT b.facture_id) FILTER (WHERE b.facture_id IS NOT NULL) AS nb_factures
    FROM public.rapport_apply_filters(_filtres) b
    WHERE b.produit_id IS NOT NULL
    GROUP BY b.produit_id, b.produit_code, b.produit_titre, b.niveau, b.produit_categorie
    ORDER BY qte_vendue DESC
    LIMIT _limit
  ) t;
$$;

CREATE OR REPLACE FUNCTION public.rapport_agregat(_filtres jsonb DEFAULT '{}'::jsonb, _dim text DEFAULT 'niveau')
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='public' AS $$
DECLARE _col text; _res jsonb;
BEGIN
  _col := CASE _dim
    WHEN 'niveau'       THEN 'niveau'
    WHEN 'categorie'    THEN 'produit_categorie'
    WHEN 'ville'        THEN 'client_ville'
    WHEN 'quartier'     THEN 'client_quartier'
    WHEN 'type'         THEN 'type_client'
    WHEN 'representant' THEN 'representant'
    ELSE 'niveau' END;
  EXECUTE format($f$
    SELECT COALESCE(jsonb_agg(t ORDER BY t.ca DESC), '[]'::jsonb) FROM (
      SELECT COALESCE(NULLIF(b.%I,''),'(non renseigné)') AS label,
             SUM(b.quantite)::int AS qte,
             SUM(b.total_ligne)   AS ca,
             COUNT(DISTINCT b.client_id) AS nb_clients,
             COUNT(DISTINCT b.facture_id) FILTER (WHERE b.facture_id IS NOT NULL) AS nb_factures,
             COUNT(DISTINCT b.produit_id) AS nb_produits
      FROM public.rapport_apply_filters($1) b
      GROUP BY 1
    ) t
  $f$, _col) INTO _res USING _filtres;
  RETURN _res;
END; $$;

CREATE OR REPLACE FUNCTION public.rapport_evolution(_filtres jsonb DEFAULT '{}'::jsonb, _granularite text DEFAULT 'mois')
RETURNS jsonb LANGUAGE sql STABLE SET search_path='public' AS $$
  SELECT COALESCE(jsonb_agg(t ORDER BY t.periode), '[]'::jsonb) FROM (
    SELECT to_char(date_trunc(
      CASE _granularite WHEN 'jour' THEN 'day' WHEN 'semaine' THEN 'week' WHEN 'annee' THEN 'year' ELSE 'month' END,
      b.date_commande), 'YYYY-MM-DD') AS periode,
      SUM(b.quantite)::int AS qte,
      SUM(b.total_ligne)   AS ca,
      COUNT(DISTINCT b.commande_id) AS nb_commandes
    FROM public.rapport_apply_filters(_filtres) b
    GROUP BY 1
  ) t;
$$;

CREATE OR REPLACE FUNCTION public.rapport_produits(
  _filtres jsonb DEFAULT '{}'::jsonb,
  _tri text DEFAULT 'ca',
  _sens text DEFAULT 'desc',
  _limit int DEFAULT 100,
  _offset int DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='public' AS $$
DECLARE
  _order_col text; _sens_sql text; _res jsonb;
  _total bigint; _ca_total numeric;
BEGIN
  _order_col := CASE _tri
    WHEN 'code' THEN 'code' WHEN 'titre' THEN 'titre'
    WHEN 'qte' THEN 'qte_vendue' WHEN 'stock' THEN 'stock_actuel'
    ELSE 'ca' END;
  _sens_sql := CASE WHEN lower(_sens)='asc' THEN 'ASC' ELSE 'DESC' END;

  WITH b AS (SELECT * FROM public.rapport_apply_filters(_filtres)),
  agg AS (
    SELECT b.produit_id, MAX(b.produit_code) AS code, MAX(b.produit_titre) AS titre,
           MAX(b.niveau) AS niveau, MAX(b.produit_categorie) AS categorie,
           MAX(b.prix_vente) AS prix_unitaire,
           COALESCE(SUM(b.quantite),0)::int AS qte_vendue,
           COALESCE(SUM(CASE WHEN b.facture_id IS NOT NULL THEN b.quantite END),0)::int AS qte_facturee,
           COUNT(DISTINCT b.facture_id) FILTER (WHERE b.facture_id IS NOT NULL) AS nb_factures,
           COUNT(DISTINCT b.client_id) AS nb_clients,
           COALESCE(SUM(b.total_ligne),0) AS ca,
           COALESCE(SUM(b.montant_remise),0) AS remises
    FROM b WHERE b.produit_id IS NOT NULL
    GROUP BY b.produit_id
  ),
  enr AS (
    SELECT a.*,
      COALESCE(p.stock,0) AS stock_actuel,
      COALESCE(p.stock,0) AS stock_initial,
      COALESCE(p.stock,0) AS stock_restant,
      0 AS qte_retournee,
      CASE WHEN (SELECT SUM(ca) FROM agg)>0 THEN ROUND(a.ca*100.0/(SELECT SUM(ca) FROM agg),2) ELSE 0 END AS pct_ca
    FROM agg a LEFT JOIN public.produits p ON p.produit_id=a.produit_id
  ),
  ranked AS (
    SELECT e.*, ROW_NUMBER() OVER (ORDER BY e.ca DESC) AS rang FROM enr e
  )
  SELECT COUNT(*), COALESCE(SUM(ca),0) INTO _total, _ca_total FROM ranked;

  EXECUTE format($f$
    SELECT jsonb_build_object(
      'total',$3,'ca_total',$4,
      'items', COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb))
    FROM (
      WITH b AS (SELECT * FROM public.rapport_apply_filters($1)),
      agg AS (
        SELECT b.produit_id, MAX(b.produit_code) AS code, MAX(b.produit_titre) AS titre,
               MAX(b.niveau) AS niveau, MAX(b.produit_categorie) AS categorie,
               MAX(b.prix_vente) AS prix_unitaire,
               COALESCE(SUM(b.quantite),0)::int AS qte_vendue,
               COALESCE(SUM(CASE WHEN b.facture_id IS NOT NULL THEN b.quantite END),0)::int AS qte_facturee,
               COUNT(DISTINCT b.facture_id) FILTER (WHERE b.facture_id IS NOT NULL) AS nb_factures,
               COUNT(DISTINCT b.client_id) AS nb_clients,
               COALESCE(SUM(b.total_ligne),0) AS ca,
               COALESCE(SUM(b.montant_remise),0) AS remises
        FROM b WHERE b.produit_id IS NOT NULL
        GROUP BY b.produit_id
      ),
      enr AS (
        SELECT a.*, COALESCE(p.stock,0) AS stock_actuel,
               COALESCE(p.stock,0) AS stock_initial, COALESCE(p.stock,0) AS stock_restant,
               0 AS qte_retournee,
               CASE WHEN (SELECT SUM(ca) FROM agg)>0 THEN ROUND(a.ca*100.0/(SELECT SUM(ca) FROM agg),2) ELSE 0 END AS pct_ca
        FROM agg a LEFT JOIN public.produits p ON p.produit_id=a.produit_id
      ),
      ranked AS (SELECT e.*, ROW_NUMBER() OVER (ORDER BY e.ca DESC) AS rang FROM enr e)
      SELECT * FROM ranked ORDER BY %I %s NULLS LAST LIMIT $2 OFFSET $5
    ) t
  $f$, _order_col, _sens_sql) INTO _res USING _filtres, _limit, _total, _ca_total, _offset;

  RETURN _res;
END; $$;
