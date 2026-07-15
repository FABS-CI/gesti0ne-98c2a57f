
-- MODULE RAPPORTS — Vues + RPC (SECURITY INVOKER, aucune duplication)

CREATE OR REPLACE VIEW public.v_ventes_produits
WITH (security_invoker = true) AS
SELECT
  cl.ligne_id,
  cl.commande_id,
  co.reference        AS commande_reference,
  co.statut           AS commande_statut,
  co.date_commande,
  f.facture_id,
  co.depot_id,
  co.client_id,
  COALESCE(co.client_nom, c.nom) AS client_nom,
  c.type_client,
  c.representant,
  c.ville             AS client_ville,
  c.quartier          AS client_quartier,
  c.pays              AS client_pays,
  c.categorie         AS client_categorie,
  cl.produit_id,
  p.reference         AS produit_code,
  COALESCE(p.titre, cl.designation) AS produit_titre,
  p.niveau,
  p.categorie         AS produit_categorie,
  p.prix_vente,
  cl.quantite,
  cl.prix_unitaire,
  COALESCE(cl.remise_pct, 0)      AS remise_pct,
  COALESCE(cl.montant_remise, 0)  AS montant_remise,
  COALESCE(cl.total_ht_ligne, cl.total_ligne, 0) AS total_ligne
FROM public.commande_lignes cl
JOIN public.commandes co   ON co.commande_id = cl.commande_id
LEFT JOIN public.factures f ON f.commande_id = co.commande_id
LEFT JOIN public.clients c ON c.client_id   = co.client_id
LEFT JOIN public.produits p ON p.produit_id = cl.produit_id
WHERE COALESCE(co.statut, '') NOT IN ('annulee', 'brouillon');

GRANT SELECT ON public.v_ventes_produits TO authenticated, service_role;

CREATE OR REPLACE VIEW public.v_retours_produits
WITH (security_invoker = true) AS
SELECT
  rl.produit_id,
  r.date_retour,
  r.client_id,
  rl.quantite,
  rl.total_ligne
FROM public.retour_lignes rl
JOIN public.retours r ON r.retour_id = rl.retour_id
WHERE COALESCE(r.statut, '') NOT IN ('annule', 'annulee');

GRANT SELECT ON public.v_retours_produits TO authenticated, service_role;

-- Rapport détaillé produits
CREATE OR REPLACE FUNCTION public.rapport_produits(
  _filtres jsonb DEFAULT '{}'::jsonb,
  _tri text DEFAULT 'ca',
  _sens text DEFAULT 'desc',
  _limit int DEFAULT 100,
  _offset int DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER STABLE SET search_path = public AS $$
DECLARE
  _from date := NULLIF(_filtres->>'from','')::date;
  _to   date := NULLIF(_filtres->>'to','')::date;
  _produits uuid[]   := ARRAY(SELECT (jsonb_array_elements_text(COALESCE(_filtres->'produits','[]'::jsonb)))::uuid);
  _niveaux text[]    := ARRAY(SELECT jsonb_array_elements_text(COALESCE(_filtres->'niveaux','[]'::jsonb)));
  _categories text[] := ARRAY(SELECT jsonb_array_elements_text(COALESCE(_filtres->'categories','[]'::jsonb)));
  _types text[]      := ARRAY(SELECT jsonb_array_elements_text(COALESCE(_filtres->'types','[]'::jsonb)));
  _villes text[]     := ARRAY(SELECT jsonb_array_elements_text(COALESCE(_filtres->'villes','[]'::jsonb)));
  _reps text[]       := ARRAY(SELECT jsonb_array_elements_text(COALESCE(_filtres->'representants','[]'::jsonb)));
  _statuts text[]    := ARRAY(SELECT jsonb_array_elements_text(COALESCE(_filtres->'statuts','[]'::jsonb)));
  _client_id uuid    := NULLIF(_filtres->>'client_id','')::uuid;
  _res jsonb;
  _ca_total numeric;
BEGIN
  CREATE TEMP TABLE _base ON COMMIT DROP AS
  SELECT * FROM public.v_ventes_produits v
  WHERE (_from IS NULL OR v.date_commande >= _from)
    AND (_to IS NULL OR v.date_commande <= _to)
    AND (cardinality(_produits)=0 OR v.produit_id = ANY(_produits))
    AND (cardinality(_niveaux)=0 OR v.niveau = ANY(_niveaux))
    AND (cardinality(_categories)=0 OR v.produit_categorie = ANY(_categories))
    AND (cardinality(_types)=0 OR v.type_client = ANY(_types))
    AND (cardinality(_villes)=0 OR v.client_ville = ANY(_villes))
    AND (cardinality(_reps)=0 OR v.representant = ANY(_reps))
    AND (cardinality(_statuts)=0 OR v.commande_statut = ANY(_statuts))
    AND (_client_id IS NULL OR v.client_id = _client_id);

  SELECT COALESCE(SUM(total_ligne),0) INTO _ca_total FROM _base;

  WITH agg AS (
    SELECT b.produit_id,
      MAX(b.produit_code)      AS code,
      MAX(b.produit_titre)     AS titre,
      MAX(b.niveau)            AS niveau,
      MAX(b.produit_categorie) AS categorie,
      AVG(b.prix_unitaire)     AS prix_unitaire_moyen,
      SUM(b.quantite)          AS qte_vendue,
      SUM(CASE WHEN b.facture_id IS NOT NULL THEN b.quantite ELSE 0 END) AS qte_facturee,
      COUNT(DISTINCT b.facture_id) FILTER (WHERE b.facture_id IS NOT NULL) AS nb_factures,
      COUNT(DISTINCT b.client_id) AS nb_clients,
      SUM(b.total_ligne)  AS ca,
      SUM(b.montant_remise) AS remises
    FROM _base b WHERE b.produit_id IS NOT NULL GROUP BY b.produit_id
  ),
  retours AS (
    SELECT produit_id, SUM(quantite) AS qte_retournee FROM public.v_retours_produits
    WHERE (_from IS NULL OR date_retour >= _from) AND (_to IS NULL OR date_retour <= _to)
    GROUP BY produit_id
  ),
  stocks AS (
    SELECT produit_id, SUM(quantite) AS stock_actuel FROM public.stocks_depots GROUP BY produit_id
  ),
  full_rows AS (
    SELECT a.produit_id, a.code, a.titre, a.niveau, a.categorie,
      ROUND(a.prix_unitaire_moyen, 2) AS prix_unitaire,
      a.qte_vendue, a.qte_facturee, a.nb_factures, a.nb_clients,
      a.ca, a.remises,
      COALESCE(r.qte_retournee, 0) AS qte_retournee,
      COALESCE(s.stock_actuel, 0)  AS stock_actuel,
      COALESCE(s.stock_actuel, 0) + a.qte_vendue AS stock_initial,
      COALESCE(s.stock_actuel, 0)  AS stock_restant,
      CASE WHEN _ca_total > 0 THEN ROUND(a.ca * 100.0 / _ca_total, 2) ELSE 0 END AS pct_ca,
      ROW_NUMBER() OVER (ORDER BY a.ca DESC) AS rang
    FROM agg a
    LEFT JOIN retours r ON r.produit_id = a.produit_id
    LEFT JOIN stocks  s ON s.produit_id = a.produit_id
  ),
  sorted AS (
    SELECT * FROM full_rows
    ORDER BY
      CASE WHEN _tri='ca'   AND _sens='desc' THEN ca END DESC NULLS LAST,
      CASE WHEN _tri='ca'   AND _sens='asc'  THEN ca END ASC  NULLS LAST,
      CASE WHEN _tri='qte'  AND _sens='desc' THEN qte_vendue END DESC NULLS LAST,
      CASE WHEN _tri='qte'  AND _sens='asc'  THEN qte_vendue END ASC  NULLS LAST,
      CASE WHEN _tri='titre' AND _sens='asc'  THEN titre END ASC,
      CASE WHEN _tri='titre' AND _sens='desc' THEN titre END DESC,
      CASE WHEN _tri='code' AND _sens='asc'  THEN code END ASC,
      CASE WHEN _tri='code' AND _sens='desc' THEN code END DESC,
      CASE WHEN _tri='stock' AND _sens='desc' THEN stock_actuel END DESC,
      CASE WHEN _tri='stock' AND _sens='asc'  THEN stock_actuel END ASC,
      ca DESC
    LIMIT _limit OFFSET _offset
  )
  SELECT jsonb_build_object(
    'total', (SELECT count(*) FROM full_rows),
    'ca_total', _ca_total,
    'items', COALESCE((SELECT jsonb_agg(to_jsonb(s)) FROM sorted s), '[]'::jsonb)
  ) INTO _res;

  RETURN COALESCE(_res, jsonb_build_object('total',0,'ca_total',0,'items','[]'::jsonb));
END; $$;

GRANT EXECUTE ON FUNCTION public.rapport_produits(jsonb,text,text,int,int) TO authenticated;

-- KPI globaux
CREATE OR REPLACE FUNCTION public.rapport_kpi(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER STABLE SET search_path = public AS $$
DECLARE
  _from date := NULLIF(_filtres->>'from','')::date;
  _to   date := NULLIF(_filtres->>'to','')::date;
  _res jsonb;
BEGIN
  WITH b AS (
    SELECT * FROM public.v_ventes_produits
    WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)
  ),
  glob AS (
    SELECT COALESCE(SUM(quantite),0) AS qte_vendue,
      COALESCE(SUM(CASE WHEN facture_id IS NOT NULL THEN quantite END),0) AS qte_facturee,
      COUNT(DISTINCT facture_id) FILTER (WHERE facture_id IS NOT NULL) AS nb_factures,
      COUNT(DISTINCT client_id) AS nb_clients,
      COALESCE(SUM(total_ligne),0) AS ca,
      COUNT(DISTINCT commande_id) AS nb_commandes
    FROM b
  ),
  top1 AS (SELECT produit_titre FROM b WHERE produit_id IS NOT NULL
           GROUP BY produit_titre ORDER BY SUM(quantite) DESC LIMIT 1),
  rent1 AS (SELECT produit_titre FROM b WHERE produit_id IS NOT NULL
            GROUP BY produit_titre ORDER BY SUM(total_ligne) DESC LIMIT 1),
  flop1 AS (SELECT produit_titre FROM b WHERE produit_id IS NOT NULL
            GROUP BY produit_titre ORDER BY SUM(quantite) ASC LIMIT 1)
  SELECT jsonb_build_object(
    'qte_vendue',(SELECT qte_vendue FROM glob),
    'qte_facturee',(SELECT qte_facturee FROM glob),
    'nb_factures',(SELECT nb_factures FROM glob),
    'nb_clients',(SELECT nb_clients FROM glob),
    'ca',(SELECT ca FROM glob),
    'nb_commandes',(SELECT nb_commandes FROM glob),
    'prix_moyen', CASE WHEN (SELECT qte_vendue FROM glob)>0
        THEN ROUND((SELECT ca FROM glob)/(SELECT qte_vendue FROM glob),2) ELSE 0 END,
    'panier_moyen', CASE WHEN (SELECT nb_factures FROM glob)>0
        THEN ROUND((SELECT ca FROM glob)/(SELECT nb_factures FROM glob),2) ELSE 0 END,
    'top_produit',(SELECT produit_titre FROM top1),
    'rentable_produit',(SELECT produit_titre FROM rent1),
    'flop_produit',(SELECT produit_titre FROM flop1)
  ) INTO _res;
  RETURN _res;
END; $$;
GRANT EXECUTE ON FUNCTION public.rapport_kpi(jsonb) TO authenticated;

-- Top produits
CREATE OR REPLACE FUNCTION public.rapport_top_produits(
  _filtres jsonb DEFAULT '{}'::jsonb, _limit int DEFAULT 20
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER STABLE SET search_path=public AS $$
DECLARE
  _from date := NULLIF(_filtres->>'from','')::date;
  _to   date := NULLIF(_filtres->>'to','')::date;
  _res jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb) INTO _res FROM (
    SELECT produit_id, MAX(produit_code) code, MAX(produit_titre) titre,
      MAX(niveau) niveau, MAX(produit_categorie) categorie,
      SUM(quantite) qte_vendue, SUM(total_ligne) ca,
      COUNT(DISTINCT client_id) nb_clients,
      COUNT(DISTINCT facture_id) FILTER (WHERE facture_id IS NOT NULL) nb_factures
    FROM public.v_ventes_produits
    WHERE produit_id IS NOT NULL
      AND (_from IS NULL OR date_commande >= _from)
      AND (_to IS NULL OR date_commande <= _to)
    GROUP BY produit_id ORDER BY qte_vendue DESC NULLS LAST LIMIT _limit
  ) t;
  RETURN _res;
END; $$;
GRANT EXECUTE ON FUNCTION public.rapport_top_produits(jsonb,int) TO authenticated;

-- Flop produits
CREATE OR REPLACE FUNCTION public.rapport_flop_produits(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER STABLE SET search_path=public AS $$
DECLARE
  _from date := NULLIF(_filtres->>'from','')::date;
  _to   date := NULLIF(_filtres->>'to','')::date;
  _res jsonb;
BEGIN
  WITH ventes AS (
    SELECT produit_id, SUM(quantite) qte, SUM(total_ligne) ca
    FROM public.v_ventes_produits
    WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)
    GROUP BY produit_id
  ),
  base AS (
    SELECT p.produit_id, p.reference code, p.titre, p.niveau, p.categorie,
      COALESCE(v.qte,0) qte, COALESCE(v.ca,0) ca
    FROM public.produits p LEFT JOIN ventes v ON v.produit_id=p.produit_id
    WHERE p.actif = true
  )
  SELECT jsonb_build_object(
    'jamais_vendus', COALESCE((SELECT jsonb_agg(row_to_json(x)) FROM (
      SELECT code,titre,niveau,categorie FROM base WHERE qte=0 LIMIT 200) x),'[]'::jsonb),
    'peu_vendus', COALESCE((SELECT jsonb_agg(row_to_json(x)) FROM (
      SELECT code,titre,niveau,categorie,qte,ca FROM base WHERE qte>0 AND qte<5
      ORDER BY qte ASC LIMIT 100) x),'[]'::jsonb)
  ) INTO _res;
  RETURN _res;
END; $$;
GRANT EXECUTE ON FUNCTION public.rapport_flop_produits(jsonb) TO authenticated;

-- Agrégats par dimension
CREATE OR REPLACE FUNCTION public.rapport_agregat(
  _filtres jsonb DEFAULT '{}'::jsonb, _dim text DEFAULT 'niveau'
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER STABLE SET search_path=public AS $$
DECLARE
  _from date := NULLIF(_filtres->>'from','')::date;
  _to   date := NULLIF(_filtres->>'to','')::date;
  _res jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t) ORDER BY (row_to_json(t)->>'ca')::numeric DESC),'[]'::jsonb)
  INTO _res FROM (
    SELECT
      CASE _dim
        WHEN 'niveau'    THEN COALESCE(niveau,'—')
        WHEN 'categorie' THEN COALESCE(produit_categorie,'—')
        WHEN 'ville'     THEN COALESCE(client_ville,'—')
        WHEN 'quartier'  THEN COALESCE(client_quartier,'—')
        WHEN 'type'      THEN COALESCE(type_client,'—')
        WHEN 'representant' THEN COALESCE(representant,'—')
        ELSE '—' END AS label,
      SUM(quantite) qte, SUM(total_ligne) ca,
      COUNT(DISTINCT client_id) nb_clients,
      COUNT(DISTINCT facture_id) FILTER (WHERE facture_id IS NOT NULL) nb_factures,
      COUNT(DISTINCT produit_id) nb_produits
    FROM public.v_ventes_produits
    WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)
    GROUP BY 1
  ) t;
  RETURN _res;
END; $$;
GRANT EXECUTE ON FUNCTION public.rapport_agregat(jsonb,text) TO authenticated;

-- Clients d'un produit
CREATE OR REPLACE FUNCTION public.rapport_clients_produit(
  _produit_id uuid, _filtres jsonb DEFAULT '{}'::jsonb, _limit int DEFAULT 100
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER STABLE SET search_path=public AS $$
DECLARE
  _from date := NULLIF(_filtres->>'from','')::date;
  _to   date := NULLIF(_filtres->>'to','')::date;
  _res jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)),'[]'::jsonb) INTO _res FROM (
    SELECT client_id, MAX(client_nom) client_nom, MAX(type_client) type_client,
      MAX(client_ville) ville, SUM(quantite) qte, SUM(total_ligne) ca,
      COUNT(DISTINCT commande_id) nb_commandes,
      MIN(date_commande) premiere, MAX(date_commande) derniere
    FROM public.v_ventes_produits
    WHERE produit_id = _produit_id
      AND (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)
    GROUP BY client_id ORDER BY ca DESC NULLS LAST LIMIT _limit
  ) t;
  RETURN _res;
END; $$;
GRANT EXECUTE ON FUNCTION public.rapport_clients_produit(uuid,jsonb,int) TO authenticated;

-- Évolution temporelle
CREATE OR REPLACE FUNCTION public.rapport_evolution(
  _filtres jsonb DEFAULT '{}'::jsonb, _granularite text DEFAULT 'mois'
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER STABLE SET search_path=public AS $$
DECLARE
  _from date := NULLIF(_filtres->>'from','')::date;
  _to   date := NULLIF(_filtres->>'to','')::date;
  _trunc text := CASE _granularite WHEN 'jour' THEN 'day' WHEN 'semaine' THEN 'week'
                                    WHEN 'annee' THEN 'year' ELSE 'month' END;
  _res jsonb;
BEGIN
  EXECUTE format($f$
    SELECT COALESCE(jsonb_agg(row_to_json(t) ORDER BY t.periode),'[]'::jsonb) FROM (
      SELECT to_char(date_trunc(%L, date_commande),'YYYY-MM-DD') periode,
        SUM(quantite) qte, SUM(total_ligne) ca, COUNT(DISTINCT commande_id) nb_commandes
      FROM public.v_ventes_produits
      WHERE (%L::date IS NULL OR date_commande >= %L::date)
        AND (%L::date IS NULL OR date_commande <= %L::date)
      GROUP BY 1) t
  $f$, _trunc, _from, _from, _to, _to) INTO _res;
  RETURN _res;
END; $$;
GRANT EXECUTE ON FUNCTION public.rapport_evolution(jsonb,text) TO authenticated;

CREATE INDEX IF NOT EXISTS idx_commande_lignes_produit ON public.commande_lignes(produit_id);
CREATE INDEX IF NOT EXISTS idx_commandes_date          ON public.commandes(date_commande);
CREATE INDEX IF NOT EXISTS idx_factures_commande       ON public.factures(commande_id);
CREATE INDEX IF NOT EXISTS idx_retour_lignes_produit   ON public.retour_lignes(produit_id);
CREATE INDEX IF NOT EXISTS idx_stocks_depots_produit   ON public.stocks_depots(produit_id);
