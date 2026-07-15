-- Perf v3 : RPC pour lire les hotspots pg_stat_statements (admin uniquement)
CREATE OR REPLACE FUNCTION public.perf_hotspots_top(p_limit int DEFAULT 20)
RETURNS TABLE (
  query text,
  calls bigint,
  total_ms numeric,
  mean_ms numeric,
  max_ms numeric,
  rows_avg numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NOT public.has_role(auth.uid(), 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;

  RETURN QUERY
  SELECT
    s.query::text,
    s.calls::bigint,
    ROUND(s.total_exec_time::numeric, 2)  AS total_ms,
    ROUND(s.mean_exec_time::numeric, 2)   AS mean_ms,
    ROUND(s.max_exec_time::numeric, 2)    AS max_ms,
    ROUND((s.rows::numeric / NULLIF(s.calls, 0)), 1) AS rows_avg
  FROM extensions.pg_stat_statements s
  JOIN pg_database d ON d.oid = s.dbid
  WHERE d.datname = current_database()
    AND s.query NOT ILIKE '%pg_stat_statements%'
    AND s.query NOT ILIKE '%information_schema%'
    AND s.query NOT ILIKE '%pg_catalog%'
  ORDER BY s.total_exec_time DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE ALL ON FUNCTION public.perf_hotspots_top(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.perf_hotspots_top(int) TO authenticated;