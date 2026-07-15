
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

CREATE OR REPLACE FUNCTION public.audit_events_stats(
  p_module text DEFAULT NULL,
  p_period_days int DEFAULT NULL,
  p_user_email text DEFAULT NULL,
  p_action text DEFAULT NULL,
  p_search text DEFAULT NULL
)
RETURNS TABLE (
  total_events bigint,
  unique_users bigint,
  today_events bigint,
  connected_15min bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH filtered AS (
    SELECT *
    FROM public.audit_events
    WHERE (p_module IS NULL OR table_name = p_module)
      AND (p_period_days IS NULL OR occurred_at >= now() - make_interval(days => p_period_days))
      AND (p_user_email IS NULL OR user_email = p_user_email)
      AND (p_action IS NULL OR action::text = p_action)
      AND (
        p_search IS NULL
        OR user_email  ILIKE '%'||p_search||'%'
        OR table_name  ILIKE '%'||p_search||'%'
        OR record_id   ILIKE '%'||p_search||'%'
        OR action::text ILIKE '%'||p_search||'%'
      )
  )
  SELECT
    (SELECT count(*) FROM filtered),
    (SELECT count(DISTINCT user_email) FROM filtered WHERE user_email IS NOT NULL),
    (SELECT count(*) FROM filtered WHERE occurred_at::date = current_date),
    (SELECT count(DISTINCT COALESCE(user_email, user_id::text))
       FROM filtered WHERE occurred_at >= now() - interval '15 minutes');
$$;

GRANT EXECUTE ON FUNCTION public.audit_events_stats(text, int, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_events_stats(text, int, text, text, text) TO service_role;

CREATE OR REPLACE FUNCTION public.audit_events_list(
  p_module text DEFAULT NULL,
  p_period_days int DEFAULT NULL,
  p_user_email text DEFAULT NULL,
  p_action text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  user_email text,
  user_id uuid,
  action text,
  module text,
  table_name text,
  record_id text,
  record_ref text,
  occurred_at timestamptz,
  old_values jsonb,
  new_values jsonb,
  changes jsonb,
  ip_address text,
  user_agent text,
  url text,
  http_method text,
  status text,
  duration_ms int,
  total_count bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH filtered AS (
    SELECT *
    FROM public.audit_events
    WHERE (p_module IS NULL OR table_name = p_module)
      AND (p_period_days IS NULL OR occurred_at >= now() - make_interval(days => p_period_days))
      AND (p_user_email IS NULL OR user_email = p_user_email)
      AND (p_action IS NULL OR action::text = p_action)
      AND (
        p_search IS NULL
        OR user_email  ILIKE '%'||p_search||'%'
        OR table_name  ILIKE '%'||p_search||'%'
        OR record_id   ILIKE '%'||p_search||'%'
        OR action::text ILIKE '%'||p_search||'%'
      )
  ),
  counted AS (SELECT count(*)::bigint AS c FROM filtered)
  SELECT
    f.id,
    f.user_email,
    f.user_id,
    f.action::text,
    f.module,
    f.table_name,
    f.record_id,
    f.record_ref,
    f.occurred_at,
    f.old_values,
    f.new_values,
    f.changes,
    f.ip_address::text,
    f.user_agent,
    f.url,
    f.http_method,
    f.status,
    f.duration_ms,
    (SELECT c FROM counted)
  FROM filtered f
  ORDER BY f.occurred_at DESC
  LIMIT GREATEST(p_limit, 1) OFFSET GREATEST(p_offset, 0);
$$;

GRANT EXECUTE ON FUNCTION public.audit_events_list(text, int, text, text, text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_events_list(text, int, text, text, text, int, int) TO service_role;

CREATE OR REPLACE FUNCTION public.factures_list_paginated(
  p_q text DEFAULT NULL,
  p_statut text DEFAULT NULL,
  p_exercice_id uuid DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_client text DEFAULT NULL,
  p_client_ids uuid[] DEFAULT NULL,
  p_commande_ids uuid[] DEFAULT NULL,
  p_date_du date DEFAULT NULL,
  p_date_au date DEFAULT NULL,
  p_montant_min numeric DEFAULT NULL,
  p_montant_max numeric DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  facture_id uuid,
  reference text,
  client_id uuid,
  client_nom text,
  commande_id uuid,
  date_facture date,
  date_echeance date,
  montant_total numeric,
  montant_paye numeric,
  statut text,
  notes text,
  created_at timestamptz,
  updated_at timestamptz,
  total_count bigint,
  sum_montant_total numeric,
  sum_montant_paye numeric
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH filtered AS (
    SELECT *
    FROM public.factures f
    WHERE (p_exercice_id  IS NULL OR f.exercice_id  = p_exercice_id)
      AND (p_statut       IS NULL OR f.statut::text = p_statut)
      AND (p_reference    IS NULL OR f.reference    ILIKE '%'||p_reference||'%')
      AND (p_client       IS NULL OR f.client_nom   ILIKE '%'||p_client||'%')
      AND (p_q            IS NULL OR f.reference    ILIKE '%'||p_q||'%' OR f.client_nom ILIKE '%'||p_q||'%')
      AND (p_client_ids   IS NULL OR f.client_id    = ANY(p_client_ids))
      AND (p_commande_ids IS NULL OR f.commande_id  = ANY(p_commande_ids))
      AND (p_date_du      IS NULL OR f.date_facture >= p_date_du)
      AND (p_date_au      IS NULL OR f.date_facture <= p_date_au)
      AND (p_montant_min  IS NULL OR f.montant_total >= p_montant_min)
      AND (p_montant_max  IS NULL OR f.montant_total <= p_montant_max)
  ),
  agg AS (
    SELECT
      count(*)::bigint AS total_count,
      COALESCE(SUM(CASE WHEN statut::text <> 'annulee' THEN montant_total ELSE 0 END), 0) AS sum_mt,
      COALESCE(SUM(CASE WHEN statut::text <> 'annulee' THEN montant_paye  ELSE 0 END), 0) AS sum_mp
    FROM filtered
  )
  SELECT
    f.facture_id, f.reference, f.client_id, f.client_nom, f.commande_id,
    f.date_facture, f.date_echeance, f.montant_total, f.montant_paye,
    f.statut::text, f.notes, f.created_at, f.updated_at,
    (SELECT total_count FROM agg),
    (SELECT sum_mt      FROM agg),
    (SELECT sum_mp      FROM agg)
  FROM filtered f
  ORDER BY f.created_at DESC
  LIMIT GREATEST(p_limit, 1) OFFSET GREATEST(p_offset, 0);
$$;

GRANT EXECUTE ON FUNCTION public.factures_list_paginated(text, text, uuid, text, text, uuid[], uuid[], date, date, numeric, numeric, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.factures_list_paginated(text, text, uuid, text, text, uuid[], uuid[], date, date, numeric, numeric, int, int) TO service_role;
