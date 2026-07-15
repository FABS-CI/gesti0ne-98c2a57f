
-- Index d'appui
CREATE INDEX IF NOT EXISTS idx_commande_lignes_produit ON public.commande_lignes(produit_id);
CREATE INDEX IF NOT EXISTS idx_commandes_client_date ON public.commandes(client_id, date_commande DESC);

-- Vue lignes d'achats enrichies
CREATE OR REPLACE VIEW public.v_client_achats
WITH (security_invoker = true) AS
SELECT
  c.client_id,
  c.nom             AS client_nom,
  c.type_client,
  c.ville,
  c.representant,
  cmd.commande_id,
  cmd.reference     AS commande_reference,
  cmd.date_commande,
  cmd.statut        AS commande_statut,
  cl.ligne_id,
  cl.produit_id,
  cl.designation    AS produit_titre,
  cl.reference_produit,
  p.niveau,
  p.categorie,
  p.categorie_id,
  cl.quantite,
  cl.prix_unitaire,
  cl.remise_pct,
  cl.total_ligne,
  cl.total_ht_ligne
FROM public.commandes cmd
JOIN public.commande_lignes cl ON cl.commande_id = cmd.commande_id
LEFT JOIN public.produits p     ON p.produit_id = cl.produit_id
LEFT JOIN public.clients c      ON c.client_id = cmd.client_id
WHERE cmd.statut NOT IN ('brouillon','annulee','annulee_client');

-- Vue statistiques par client
CREATE OR REPLACE VIEW public.v_client_stats
WITH (security_invoker = true) AS
WITH base AS (
  SELECT
    client_id,
    COUNT(DISTINCT commande_id)                 AS nb_commandes,
    COALESCE(SUM(total_ligne),0)                AS ca_total,
    COALESCE(SUM(quantite),0)                   AS qte_totale,
    MIN(date_commande)                          AS premiere_commande,
    MAX(date_commande)                          AS derniere_commande
  FROM public.v_client_achats
  WHERE client_id IS NOT NULL
  GROUP BY client_id
),
top_produit AS (
  SELECT DISTINCT ON (client_id)
    client_id, produit_titre AS top_produit
  FROM public.v_client_achats
  WHERE client_id IS NOT NULL
  GROUP BY client_id, produit_titre
  ORDER BY client_id, SUM(quantite) DESC
),
top_categorie AS (
  SELECT DISTINCT ON (client_id)
    client_id, categorie AS top_categorie
  FROM public.v_client_achats
  WHERE client_id IS NOT NULL AND categorie IS NOT NULL
  GROUP BY client_id, categorie
  ORDER BY client_id, SUM(quantite) DESC
),
top_niveau AS (
  SELECT DISTINCT ON (client_id)
    client_id, niveau AS top_niveau
  FROM public.v_client_achats
  WHERE client_id IS NOT NULL AND niveau IS NOT NULL
  GROUP BY client_id, niveau
  ORDER BY client_id, SUM(quantite) DESC
)
SELECT
  b.client_id,
  b.nb_commandes,
  b.ca_total,
  b.qte_totale,
  CASE WHEN b.nb_commandes > 0 THEN ROUND(b.ca_total / b.nb_commandes, 0) ELSE 0 END AS ticket_moyen,
  b.premiere_commande,
  b.derniere_commande,
  tp.top_produit,
  tc.top_categorie,
  tn.top_niveau
FROM base b
LEFT JOIN top_produit tp   USING (client_id)
LEFT JOIN top_categorie tc USING (client_id)
LEFT JOIN top_niveau tn    USING (client_id);

GRANT SELECT ON public.v_client_achats TO authenticated;
GRANT SELECT ON public.v_client_stats  TO authenticated;

-- RPC : recherche CRM
CREATE OR REPLACE FUNCTION public.search_clients_crm(
  _filters jsonb DEFAULT '{}'::jsonb,
  _limit   int   DEFAULT 20,
  _offset  int   DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  _q            text := NULLIF(trim(coalesce(_filters->>'q','')), '');
  _produits     uuid[] := CASE WHEN _filters ? 'produits' THEN
                    ARRAY(SELECT jsonb_array_elements_text(_filters->'produits'))::uuid[] END;
  _niveaux      text[] := CASE WHEN _filters ? 'niveaux' THEN
                    ARRAY(SELECT jsonb_array_elements_text(_filters->'niveaux')) END;
  _categories   text[] := CASE WHEN _filters ? 'categories' THEN
                    ARRAY(SELECT jsonb_array_elements_text(_filters->'categories')) END;
  _types        text[] := CASE WHEN _filters ? 'types' THEN
                    ARRAY(SELECT jsonb_array_elements_text(_filters->'types')) END;
  _villes       text[] := CASE WHEN _filters ? 'villes' THEN
                    ARRAY(SELECT jsonb_array_elements_text(_filters->'villes')) END;
  _representant text := NULLIF(_filters->>'representant','');
  _from         date := NULLIF(_filters->>'from','')::date;
  _to           date := NULLIF(_filters->>'to','')::date;
  _actif        boolean := CASE WHEN _filters ? 'actif' THEN (_filters->>'actif')::boolean END;
  _total        int;
  _items        jsonb;
BEGIN
  CREATE TEMP TABLE _matches ON COMMIT DROP AS
  SELECT DISTINCT c.client_id
  FROM public.clients c
  LEFT JOIN public.v_client_achats va ON va.client_id = c.client_id
  WHERE
    (_actif IS NULL OR c.actif = _actif)
    AND (_types      IS NULL OR c.type_client = ANY(_types))
    AND (_villes     IS NULL OR c.ville = ANY(_villes))
    AND (_representant IS NULL OR c.representant ILIKE '%'||_representant||'%')
    AND (_q IS NULL OR
         c.nom ILIKE '%'||_q||'%' OR
         c.reference ILIKE '%'||_q||'%' OR
         c.telephone ILIKE '%'||_q||'%' OR
         c.representant ILIKE '%'||_q||'%' OR
         c.ville ILIKE '%'||_q||'%')
    AND (_produits   IS NULL OR va.produit_id = ANY(_produits))
    AND (_niveaux    IS NULL OR va.niveau = ANY(_niveaux))
    AND (_categories IS NULL OR va.categorie = ANY(_categories))
    AND (_from IS NULL OR va.date_commande >= _from)
    AND (_to   IS NULL OR va.date_commande <= _to)
    AND (
      (_produits IS NULL AND _niveaux IS NULL AND _categories IS NULL AND _from IS NULL AND _to IS NULL)
      OR va.client_id IS NOT NULL
    );

  SELECT count(*) INTO _total FROM _matches;

  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) INTO _items FROM (
    SELECT c.*,
           s.nb_commandes, s.ca_total, s.qte_totale, s.ticket_moyen,
           s.premiere_commande, s.derniere_commande,
           s.top_produit, s.top_categorie, s.top_niveau
    FROM _matches m
    JOIN public.clients c ON c.client_id = m.client_id
    LEFT JOIN public.v_client_stats s ON s.client_id = c.client_id
    ORDER BY COALESCE(s.ca_total, 0) DESC, c.nom ASC
    LIMIT _limit OFFSET _offset
  ) t;

  RETURN jsonb_build_object('total', _total, 'items', _items);
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_clients_crm(jsonb,int,int) TO authenticated;

-- RPC : historique client
CREATE OR REPLACE FUNCTION public.client_historique(_client_id uuid)
RETURNS TABLE (
  commande_id uuid,
  commande_reference text,
  date_commande date,
  commande_statut text,
  produit_id uuid,
  produit_titre text,
  reference_produit text,
  niveau text,
  categorie text,
  quantite int,
  prix_unitaire numeric,
  remise_pct numeric,
  total_ligne numeric
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT commande_id, commande_reference, date_commande, commande_statut,
         produit_id, produit_titre, reference_produit, niveau, categorie,
         quantite, prix_unitaire, remise_pct, total_ligne
  FROM public.v_client_achats
  WHERE client_id = _client_id
  ORDER BY date_commande DESC, commande_reference DESC;
$$;

GRANT EXECUTE ON FUNCTION public.client_historique(uuid) TO authenticated;

-- RPC : dashboard commercial
CREATE OR REPLACE FUNCTION public.crm_dashboard(
  _from date DEFAULT (CURRENT_DATE - INTERVAL '12 months')::date,
  _to   date DEFAULT CURRENT_DATE
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  _res jsonb;
BEGIN
  WITH base AS (
    SELECT * FROM public.v_client_achats
    WHERE date_commande BETWEEN _from AND _to
  )
  SELECT jsonb_build_object(
    'ca_total',       (SELECT COALESCE(SUM(total_ligne),0) FROM base),
    'nb_commandes',   (SELECT COUNT(DISTINCT commande_id) FROM base),
    'nb_clients',     (SELECT COUNT(DISTINCT client_id) FROM base),
    'par_niveau',     (SELECT COALESCE(jsonb_agg(x),'[]'::jsonb) FROM (
                        SELECT niveau AS label, SUM(total_ligne) AS ca, SUM(quantite) AS qte
                        FROM base WHERE niveau IS NOT NULL
                        GROUP BY niveau ORDER BY ca DESC) x),
    'par_categorie',  (SELECT COALESCE(jsonb_agg(x),'[]'::jsonb) FROM (
                        SELECT categorie AS label, SUM(total_ligne) AS ca, SUM(quantite) AS qte
                        FROM base WHERE categorie IS NOT NULL
                        GROUP BY categorie ORDER BY ca DESC) x),
    'par_ville',      (SELECT COALESCE(jsonb_agg(x),'[]'::jsonb) FROM (
                        SELECT ville AS label, SUM(total_ligne) AS ca
                        FROM base WHERE ville IS NOT NULL
                        GROUP BY ville ORDER BY ca DESC LIMIT 20) x),
    'par_type_client',(SELECT COALESCE(jsonb_agg(x),'[]'::jsonb) FROM (
                        SELECT type_client AS label, SUM(total_ligne) AS ca, COUNT(DISTINCT client_id) AS nb
                        FROM base WHERE type_client IS NOT NULL
                        GROUP BY type_client ORDER BY ca DESC) x),
    'top_produits',   (SELECT COALESCE(jsonb_agg(x),'[]'::jsonb) FROM (
                        SELECT produit_titre AS label, SUM(quantite) AS qte, SUM(total_ligne) AS ca
                        FROM base WHERE produit_titre IS NOT NULL
                        GROUP BY produit_titre ORDER BY qte DESC LIMIT 20) x),
    'flop_produits',  (SELECT COALESCE(jsonb_agg(x),'[]'::jsonb) FROM (
                        SELECT produit_titre AS label, SUM(quantite) AS qte, SUM(total_ligne) AS ca
                        FROM base WHERE produit_titre IS NOT NULL
                        GROUP BY produit_titre ORDER BY qte ASC LIMIT 20) x),
    'ca_mensuel',     (SELECT COALESCE(jsonb_agg(x ORDER BY mois),'[]'::jsonb) FROM (
                        SELECT to_char(date_trunc('month', date_commande),'YYYY-MM') AS mois,
                               SUM(total_ligne) AS ca,
                               COUNT(DISTINCT commande_id) AS nb
                        FROM base
                        GROUP BY 1) x),
    'top_clients',    (SELECT COALESCE(jsonb_agg(x),'[]'::jsonb) FROM (
                        SELECT client_id, client_nom, type_client, ville,
                               SUM(total_ligne) AS ca,
                               COUNT(DISTINCT commande_id) AS nb
                        FROM base WHERE client_id IS NOT NULL
                        GROUP BY client_id, client_nom, type_client, ville
                        ORDER BY ca DESC LIMIT 20) x),
    'top_representants',(SELECT COALESCE(jsonb_agg(x),'[]'::jsonb) FROM (
                        SELECT representant AS label,
                               SUM(total_ligne) AS ca,
                               COUNT(DISTINCT client_id) AS nb_clients
                        FROM base WHERE representant IS NOT NULL
                        GROUP BY representant ORDER BY ca DESC LIMIT 20) x)
  ) INTO _res;

  RETURN _res;
END;
$$;

GRANT EXECUTE ON FUNCTION public.crm_dashboard(date,date) TO authenticated;
