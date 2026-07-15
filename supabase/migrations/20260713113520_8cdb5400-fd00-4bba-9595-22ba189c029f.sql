
DROP FUNCTION IF EXISTS public.dashboard_overview_stats(date, date);

CREATE OR REPLACE FUNCTION public.dashboard_overview_full(
  _exercice_id uuid,
  _periode_jours integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_since       date := (now() - make_interval(days => _periode_jours))::date;
  v_today       date := now()::date;
  v_result      jsonb;
  v_par_statut  jsonb;
  v_ca_mensuel  jsonb;
  v_stock_bas   jsonb;
  v_recettes    numeric;
  v_depenses    numeric;
  v_ca_total    numeric;
  v_nb_cmds     integer;
  v_nb_retards  integer;
  v_montant_ret numeric;
  v_nb_stockbas integer;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object('statut', statut, 'count', c)), '[]'::jsonb)
    INTO v_par_statut
  FROM (
    SELECT statut, COUNT(*)::int AS c
    FROM public.commandes
    WHERE exercice_id = _exercice_id AND date_commande >= v_since
    GROUP BY statut
  ) s;

  SELECT COUNT(*)::int INTO v_nb_cmds
    FROM public.commandes
    WHERE exercice_id = _exercice_id AND date_commande >= v_since;

  SELECT COALESCE(SUM(montant_total),0) INTO v_ca_total
    FROM public.factures
    WHERE exercice_id = _exercice_id AND statut <> 'annulee';

  SELECT COALESCE(jsonb_agg(row_to_json(m) ORDER BY (m.y, m.m)), '[]'::jsonb) INTO v_ca_mensuel
  FROM (
    SELECT
      EXTRACT(YEAR  FROM date_facture)::int AS y,
      EXTRACT(MONTH FROM date_facture)::int AS m,
      SUM(montant_total)::numeric AS ca,
      COUNT(*)::int AS nb
    FROM public.factures
    WHERE exercice_id = _exercice_id
      AND statut <> 'annulee'
      AND date_facture >= (date_trunc('month', now()) - interval '5 months')::date
    GROUP BY 1,2
  ) m;

  SELECT
    COALESCE(SUM(CASE WHEN type='recette' THEN montant END),0),
    COALESCE(SUM(CASE WHEN type='depense' THEN montant END),0)
    INTO v_recettes, v_depenses
  FROM public.transactions
  WHERE exercice_id = _exercice_id;

  SELECT COUNT(*)::int, COALESCE(SUM(montant_total - COALESCE(montant_paye,0)),0)
    INTO v_nb_retards, v_montant_ret
  FROM public.factures
  WHERE exercice_id = _exercice_id
    AND statut NOT IN ('payee','annulee')
    AND date_echeance IS NOT NULL
    AND date_echeance < v_today;

  SELECT COUNT(*)::int INTO v_nb_stockbas
  FROM public.v_produits
  WHERE actif = true AND stock <= seuil_alerte;

  SELECT COALESCE(jsonb_agg(row_to_json(s)), '[]'::jsonb) INTO v_stock_bas
  FROM (
    SELECT titre, stock, seuil_alerte
    FROM public.v_produits
    WHERE actif = true AND stock <= seuil_alerte
    ORDER BY stock ASC
    LIMIT 6
  ) s;

  v_result := jsonb_build_object(
    'nbCommandes',   v_nb_cmds,
    'caTotal',       v_ca_total,
    'parStatut',     v_par_statut,
    'caMensuel',     v_ca_mensuel,
    'recettes',      v_recettes,
    'depenses',      v_depenses,
    'solde',         v_recettes - v_depenses,
    'nbRetards',     v_nb_retards,
    'montantRetard', v_montant_ret,
    'nbStockBas',    v_nb_stockbas,
    'stockBas',      v_stock_bas
  );
  RETURN v_result;
END $$;

REVOKE ALL ON FUNCTION public.dashboard_overview_full(uuid, integer) FROM public;
GRANT EXECUTE ON FUNCTION public.dashboard_overview_full(uuid, integer) TO authenticated;
