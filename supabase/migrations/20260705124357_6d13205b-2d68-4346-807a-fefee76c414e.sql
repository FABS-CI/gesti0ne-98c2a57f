-- Restrict audit_events INSERT: user_id must be null or equal auth.uid()
DROP POLICY IF EXISTS "audit_events insert authenticated" ON public.audit_events;
CREATE POLICY "audit_events insert own"
  ON public.audit_events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (user_id IS NULL OR user_id = auth.uid())
  );

-- Restrict perf_query_log INSERT: user_id must be null or equal auth.uid()
DROP POLICY IF EXISTS "perf_log_insert_auth" ON public.perf_query_log;
CREATE POLICY "perf_log_insert_own"
  ON public.perf_query_log
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (user_id IS NULL OR user_id = auth.uid())
  );
