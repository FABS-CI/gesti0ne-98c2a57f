-- =====================================================================
-- LOT 1 : Correctifs KPI & Rapports d'analyse
-- =====================================================================

-- A1 : Exercices comparatif — ajoute ca_encaisse (paiements validés) + achats
DROP FUNCTION IF EXISTS public.exercices_comparatif(uuid[]);
CREATE OR REPLACE FUNCTION public.exercices_comparatif(_exercice_ids uuid[])
RETURNS TABLE(
  exercice_id uuid,
  libelle text,
  ca numeric,               -- CA facturé (SUM factures non annulées)
  encaisse numeric,         -- CA encaissé (paiements validés)
  achats numeric,           -- Total achats reçus/payés
  nb_commandes bigint,
  nb_factures bigint,
  montant_paye numeric      -- conservé pour compat éventuelle
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'comptabilite.voir') THEN
    RAISE EXCEPTION 'Permission refusée : comptabilite.voir' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    ex.exercice_id,
    ex.libelle,
    COALESCE((SELECT sum(f.montant_total) FROM public.factures f
              WHERE f.exercice_id = ex.exercice_id AND f.statut <> 'annulee'), 0)::numeric,
    COALESCE((SELECT sum(p.montant) FROM public.paiements p
              WHERE p.exercice_id = ex.exercice_id AND p.statut = 'valide'), 0)::numeric,
    COALESCE((SELECT sum(a.montant) FROM public.achats a
              WHERE a.exercice_id = ex.exercice_id
                AND a.statut IN ('receptionne','paye')), 0)::numeric,
    COALESCE((SELECT count(*) FROM public.commandes c WHERE c.exercice_id = ex.exercice_id), 0),
    COALESCE((SELECT count(*) FROM public.factures f
              WHERE f.exercice_id = ex.exercice_id AND f.statut <> 'annulee'), 0),
    COALESCE((SELECT sum(f.montant_paye) FROM public.factures f
              WHERE f.exercice_id = ex.exercice_id AND f.statut <> 'annulee'), 0)::numeric
  FROM public.exercices_comptables ex
  WHERE ex.exercice_id = ANY(_exercice_ids)
  ORDER BY ex.date_debut;
END;
$$;
REVOKE ALL ON FUNCTION public.exercices_comparatif(uuid[]) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.exercices_comparatif(uuid[]) TO authenticated;

-- =====================================================================
-- A3 : Rapports d'analyse — réimplémentation (base = factures non annulées)
-- =====================================================================

-- Helper interne : filtre commun sur commandes/factures
-- (inline dans chaque fonction pour rester en 1 seul CREATE)

-- 1) rapport_produits : liste paginée avec CA facturé par produit
CREATE OR REPLACE FUNCTION public.rapport_produits(
  _filtres jsonb DEFAULT '{}'::jsonb,
  _tri text DEFAULT 'ca',
  _sens text DEFAULT 'desc',
  _limit int DEFAULT 50,
  _offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from date := NULLIF(_filtres->>'from','')::date;
  v_to   date := NULLIF(_filtres->>'to','')::date;
  v_client uuid := NULLIF(_filtres->>'client_id','')::uuid;
  v_produits uuid[] := CASE WHEN _filtres ? 'produits'
    THEN ARRAY(SELECT jsonb_array_elements_text(_filtres->'produits'))::uuid[]
    ELSE NULL END;
  v_total int;
  v_items jsonb;
  v_ca_total numeric;
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');

  WITH lignes AS (
    SELECT cl.produit_id,
           cl.quantite,
           cl.total_ligne,
           cl.remise,
           c.client_id
    FROM public.commande_lignes cl
    JOIN public.commandes c ON c.commande_id = cl.commande_id
    JOIN public.factures f ON f.commande_id = c.commande_id
    WHERE f.statut <> 'annulee'
      AND (v_from IS NULL OR f.date_facture >= v_from)
      AND (v_to IS NULL OR f.date_facture <= v_to)
      AND (v_client IS NULL OR c.client_id = v_client)
      AND cl.produit_id IS NOT NULL
      AND (v_produits IS NULL OR cl.produit_id = ANY(v_produits))
  ),
  agg AS (
    SELECT
      p.produit_id,
      p.reference AS code,
      p.titre,
      p.niveau,
      p.categorie,
      p.prix_unitaire::numeric AS prix_unitaire,
      COALESCE(SUM(l.quantite),0)::numeric AS qte_vendue,
      COALESCE(SUM(l.quantite),0)::numeric AS qte_facturee,
      COUNT(DISTINCT l.client_id)::int AS nb_clients,
      COALESCE(SUM(l.total_ligne),0)::numeric AS ca,
      COALESCE(SUM(l.remise),0)::numeric AS remises,
      COALESCE(p.stock,0)::numeric AS stock_actuel
    FROM public.produits p
    LEFT JOIN lignes l ON l.produit_id = p.produit_id
    WHERE p.actif = true
      AND (v_produits IS NULL OR p.produit_id = ANY(v_produits))
    GROUP BY p.produit_id, p.reference, p.titre, p.niveau, p.categorie, p.prix_unitaire, p.stock
  )
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(ca),0)::numeric,
    COALESCE(jsonb_agg(jsonb_build_object(
      'produit_id', produit_id,
      'code', code,
      'titre', titre,
      'niveau', niveau,
      'categorie', categorie,
      'prix_unitaire', prix_unitaire,
      'qte_vendue', qte_vendue,
      'qte_facturee', qte_facturee,
      'nb_factures', 0,
      'nb_clients', nb_clients,
      'ca', ca,
      'remises', remises,
      'qte_retournee', 0,
      'stock_actuel', stock_actuel,
      'stock_initial', stock_actuel + qte_vendue,
      'stock_restant', stock_actuel,
      'pct_ca', 0,
      'rang', 0
    ) ORDER BY
      CASE WHEN _tri='ca'  AND _sens='desc' THEN ca END DESC NULLS LAST,
      CASE WHEN _tri='ca'  AND _sens='asc'  THEN ca END ASC NULLS LAST,
      CASE WHEN _tri='qte' AND _sens='desc' THEN qte_vendue END DESC NULLS LAST,
      CASE WHEN _tri='qte' AND _sens='asc'  THEN qte_vendue END ASC NULLS LAST,
      titre
    ), '[]'::jsonb)
  INTO v_total, v_ca_total, v_items
  FROM agg;

  RETURN jsonb_build_object(
    'total', v_total,
    'ca_total', v_ca_total,
    'items', COALESCE(
      (SELECT jsonb_agg(elem)
       FROM (SELECT elem FROM jsonb_array_elements(v_items) elem
             LIMIT _limit OFFSET _offset) sub),
      '[]'::jsonb)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.rapport_produits(jsonb,text,text,int,int) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.rapport_produits(jsonb,text,text,int,int) TO authenticated;

-- 2) rapport_top_produits
CREATE OR REPLACE FUNCTION public.rapport_top_produits(
  _filtres jsonb DEFAULT '{}'::jsonb,
  _limit int DEFAULT 20
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from date := NULLIF(_filtres->>'from','')::date;
  v_to   date := NULLIF(_filtres->>'to','')::date;
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'produit_id', p.produit_id,
      'code', p.reference,
      'titre', p.titre,
      'niveau', p.niveau,
      'categorie', p.categorie,
      'qte_vendue', s.qte,
      'ca', s.ca,
      'nb_clients', s.nb_clients,
      'nb_factures', s.nb_factures
    ) ORDER BY s.ca DESC)
    FROM (
      SELECT cl.produit_id,
             SUM(cl.quantite) AS qte,
             SUM(cl.total_ligne) AS ca,
             COUNT(DISTINCT c.client_id) AS nb_clients,
             COUNT(DISTINCT f.facture_id) AS nb_factures
      FROM public.commande_lignes cl
      JOIN public.commandes c ON c.commande_id = cl.commande_id
      JOIN public.factures f ON f.commande_id = c.commande_id
      WHERE f.statut <> 'annulee'
        AND (v_from IS NULL OR f.date_facture >= v_from)
        AND (v_to IS NULL OR f.date_facture <= v_to)
        AND cl.produit_id IS NOT NULL
      GROUP BY cl.produit_id
      ORDER BY SUM(cl.total_ligne) DESC
      LIMIT _limit
    ) s
    JOIN public.produits p ON p.produit_id = s.produit_id
  ), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.rapport_top_produits(jsonb,int) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.rapport_top_produits(jsonb,int) TO authenticated;

-- 3) rapport_flop_produits
CREATE OR REPLACE FUNCTION public.rapport_flop_produits(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from date := NULLIF(_filtres->>'from','')::date;
  v_to   date := NULLIF(_filtres->>'to','')::date;
  v_jamais jsonb; v_peu jsonb;
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');

  WITH vendus AS (
    SELECT cl.produit_id, SUM(cl.quantite) AS qte, SUM(cl.total_ligne) AS ca
    FROM public.commande_lignes cl
    JOIN public.commandes c ON c.commande_id = cl.commande_id
    JOIN public.factures f ON f.commande_id = c.commande_id
    WHERE f.statut <> 'annulee'
      AND (v_from IS NULL OR f.date_facture >= v_from)
      AND (v_to IS NULL OR f.date_facture <= v_to)
      AND cl.produit_id IS NOT NULL
    GROUP BY cl.produit_id
  )
  SELECT
    COALESCE((SELECT jsonb_agg(jsonb_build_object('code',p.reference,'titre',p.titre,'niveau',p.niveau,'categorie',p.categorie))
              FROM public.produits p
              WHERE p.actif AND NOT EXISTS (SELECT 1 FROM vendus v WHERE v.produit_id = p.produit_id)
              LIMIT 100), '[]'::jsonb),
    COALESCE((SELECT jsonb_agg(jsonb_build_object('code',p.reference,'titre',p.titre,'niveau',p.niveau,'categorie',p.categorie,'qte',v.qte,'ca',v.ca) ORDER BY v.qte ASC)
              FROM vendus v JOIN public.produits p ON p.produit_id = v.produit_id
              WHERE v.qte > 0 AND v.qte <= 5
              LIMIT 50), '[]'::jsonb)
  INTO v_jamais, v_peu;

  RETURN jsonb_build_object('jamais_vendus', v_jamais, 'peu_vendus', v_peu);
END;
$$;
REVOKE ALL ON FUNCTION public.rapport_flop_produits(jsonb) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.rapport_flop_produits(jsonb) TO authenticated;

-- 4) rapport_clients_produit
DROP FUNCTION IF EXISTS public.rapport_clients_produit(jsonb);
CREATE OR REPLACE FUNCTION public.rapport_clients_produit(
  _produit_id uuid,
  _filtres jsonb DEFAULT '{}'::jsonb,
  _limit int DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from date := NULLIF(_filtres->>'from','')::date;
  v_to   date := NULLIF(_filtres->>'to','')::date;
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'client_id', s.client_id,
      'client_nom', cl.raison_sociale,
      'type_client', cl.type_client,
      'ville', cl.ville,
      'qte', s.qte,
      'ca', s.ca,
      'nb_commandes', s.nb_commandes,
      'premiere', s.premiere,
      'derniere', s.derniere
    ) ORDER BY s.ca DESC)
    FROM (
      SELECT c.client_id,
             SUM(cl2.quantite) AS qte,
             SUM(cl2.total_ligne) AS ca,
             COUNT(DISTINCT c.commande_id) AS nb_commandes,
             MIN(c.date_commande)::text AS premiere,
             MAX(c.date_commande)::text AS derniere
      FROM public.commande_lignes cl2
      JOIN public.commandes c ON c.commande_id = cl2.commande_id
      JOIN public.factures f ON f.commande_id = c.commande_id
      WHERE f.statut <> 'annulee'
        AND cl2.produit_id = _produit_id
        AND (v_from IS NULL OR f.date_facture >= v_from)
        AND (v_to IS NULL OR f.date_facture <= v_to)
      GROUP BY c.client_id
      ORDER BY SUM(cl2.total_ligne) DESC
      LIMIT _limit
    ) s
    JOIN public.clients cl ON cl.client_id = s.client_id
  ), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.rapport_clients_produit(uuid,jsonb,int) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.rapport_clients_produit(uuid,jsonb,int) TO authenticated;

-- 5) rapport_evolution
DROP FUNCTION IF EXISTS public.rapport_evolution(jsonb);
CREATE OR REPLACE FUNCTION public.rapport_evolution(
  _filtres jsonb DEFAULT '{}'::jsonb,
  _granularite text DEFAULT 'mois'
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from date := NULLIF(_filtres->>'from','')::date;
  v_to   date := NULLIF(_filtres->>'to','')::date;
  v_trunc text := CASE _granularite
    WHEN 'jour' THEN 'day'
    WHEN 'semaine' THEN 'week'
    WHEN 'annee' THEN 'year'
    ELSE 'month'
  END;
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'periode', to_char(periode, 'YYYY-MM-DD'),
      'qte', qte,
      'ca', ca,
      'nb_commandes', nb_commandes
    ) ORDER BY periode)
    FROM (
      SELECT date_trunc(v_trunc, f.date_facture)::date AS periode,
             SUM(cl.quantite) AS qte,
             SUM(cl.total_ligne) AS ca,
             COUNT(DISTINCT c.commande_id) AS nb_commandes
      FROM public.commande_lignes cl
      JOIN public.commandes c ON c.commande_id = cl.commande_id
      JOIN public.factures f ON f.commande_id = c.commande_id
      WHERE f.statut <> 'annulee'
        AND (v_from IS NULL OR f.date_facture >= v_from)
        AND (v_to IS NULL OR f.date_facture <= v_to)
      GROUP BY 1
    ) s
  ), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.rapport_evolution(jsonb,text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.rapport_evolution(jsonb,text) TO authenticated;
