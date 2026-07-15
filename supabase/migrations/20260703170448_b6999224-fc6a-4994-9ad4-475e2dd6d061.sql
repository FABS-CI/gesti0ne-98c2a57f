CREATE TABLE public.perf_query_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query_name text NOT NULL,
  duration_ms numeric NOT NULL,
  row_count integer,
  error text,
  metadata jsonb DEFAULT '{}'::jsonb,
  user_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_perf_query_log_name_created ON public.perf_query_log(query_name, created_at DESC);
CREATE INDEX idx_perf_query_log_created ON public.perf_query_log(created_at DESC);
CREATE INDEX idx_perf_query_log_slow ON public.perf_query_log(duration_ms DESC) WHERE duration_ms > 500;

GRANT SELECT, INSERT ON public.perf_query_log TO authenticated;
GRANT ALL ON public.perf_query_log TO service_role;

ALTER TABLE public.perf_query_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "perf_log_insert_auth" ON public.perf_query_log
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "perf_log_select_admin" ON public.perf_query_log
  FOR SELECT TO authenticated
  USING (
    public.has_role(auth.uid(), 'super_admin'::app_role)
    OR public.has_role(auth.uid(), 'directeur_general'::app_role)
  );

CREATE POLICY "perf_log_delete_admin" ON public.perf_query_log
  FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));
