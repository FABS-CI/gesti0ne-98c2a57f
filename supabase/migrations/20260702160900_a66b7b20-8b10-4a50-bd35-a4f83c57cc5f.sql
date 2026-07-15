
-- 1. Table incident_alerts
CREATE TABLE public.incident_alerts (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  source TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info','warning','error','critical')),
  title TEXT NOT NULL,
  message TEXT,
  context JSONB DEFAULT '{}'::jsonb,
  resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_incident_alerts_created_at ON public.incident_alerts (created_at DESC);
CREATE INDEX idx_incident_alerts_unresolved ON public.incident_alerts (resolved, severity) WHERE resolved = false;

GRANT SELECT, UPDATE ON public.incident_alerts TO authenticated;
GRANT ALL ON public.incident_alerts TO service_role;

ALTER TABLE public.incident_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Super admins can view alerts"
  ON public.incident_alerts FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));

CREATE POLICY "Super admins can resolve alerts"
  ON public.incident_alerts FOR UPDATE
  TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));

-- 2. RPC SLO metrics (super admin only)
CREATE OR REPLACE FUNCTION public.get_slo_metrics()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_result JSONB;
  v_errors_24h INT;
  v_alerts_open INT;
  v_db_size TEXT;
  v_active_conn INT;
  v_slow_queries JSONB;
BEGIN
  IF NOT public.has_role(auth.uid(), 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'Forbidden: super_admin role required';
  END IF;

  SELECT COUNT(*) INTO v_errors_24h
  FROM public.incident_alerts
  WHERE created_at >= now() - interval '24 hours'
    AND severity IN ('error','critical');

  SELECT COUNT(*) INTO v_alerts_open
  FROM public.incident_alerts
  WHERE resolved = false;

  SELECT pg_size_pretty(pg_database_size(current_database())) INTO v_db_size;

  SELECT COUNT(*) INTO v_active_conn
  FROM pg_stat_activity
  WHERE state = 'active' AND datname = current_database();

  BEGIN
    SELECT jsonb_agg(row_to_json(q)) INTO v_slow_queries
    FROM (
      SELECT
        LEFT(query, 200) AS query,
        calls,
        ROUND(mean_exec_time::numeric, 2) AS mean_ms,
        ROUND(total_exec_time::numeric, 2) AS total_ms
      FROM pg_stat_statements
      WHERE query NOT ILIKE '%pg_stat%'
        AND query NOT ILIKE '%information_schema%'
      ORDER BY total_exec_time DESC
      LIMIT 10
    ) q;
  EXCEPTION WHEN OTHERS THEN
    v_slow_queries := '[]'::jsonb;
  END;

  v_result := jsonb_build_object(
    'errors_24h', v_errors_24h,
    'alerts_open', v_alerts_open,
    'db_size', v_db_size,
    'active_connections', v_active_conn,
    'slow_queries', COALESCE(v_slow_queries, '[]'::jsonb),
    'generated_at', now()
  );

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_slo_metrics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_slo_metrics() TO authenticated;
