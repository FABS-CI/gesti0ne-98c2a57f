
CREATE OR REPLACE FUNCTION public.audit_events_daily(p_days integer DEFAULT 30)
RETURNS TABLE (day date, info bigint, warning bigint, critical bigint, total bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH days AS (
    SELECT generate_series(
      (current_date - (p_days - 1))::date,
      current_date,
      interval '1 day'
    )::date AS day
  )
  SELECT
    d.day,
    COUNT(*) FILTER (WHERE COALESCE(e.criticite::text,'info') = 'info')     AS info,
    COUNT(*) FILTER (WHERE e.criticite::text = 'warning')                    AS warning,
    COUNT(*) FILTER (WHERE e.criticite::text = 'critical')                   AS critical,
    COUNT(e.id)                                                              AS total
  FROM days d
  LEFT JOIN public.audit_events e
    ON e.occurred_at::date = d.day
  GROUP BY d.day
  ORDER BY d.day;
$$;

CREATE OR REPLACE FUNCTION public.audit_events_by_module(p_days integer DEFAULT 30)
RETURNS TABLE (module text, total bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(NULLIF(module,''), table_name) AS module, COUNT(*) AS total
  FROM public.audit_events
  WHERE occurred_at >= now() - (p_days || ' days')::interval
  GROUP BY 1
  ORDER BY 2 DESC
  LIMIT 12;
$$;

REVOKE ALL ON FUNCTION public.audit_events_daily(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.audit_events_by_module(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audit_events_daily(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_events_by_module(integer) TO authenticated;
