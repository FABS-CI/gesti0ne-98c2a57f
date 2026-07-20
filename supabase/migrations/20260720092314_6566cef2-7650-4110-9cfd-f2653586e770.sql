
CREATE TABLE IF NOT EXISTS public.perf_web_vitals (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  metric TEXT NOT NULL CHECK (metric IN ('LCP','INP','CLS','TTFB','FCP')),
  value NUMERIC NOT NULL,
  rating TEXT NOT NULL CHECK (rating IN ('good','needs-improvement','poor')),
  route TEXT,
  url TEXT,
  navigation_type TEXT,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT ON public.perf_web_vitals TO authenticated;
GRANT ALL ON public.perf_web_vitals TO service_role;

ALTER TABLE public.perf_web_vitals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users insert own vitals"
  ON public.perf_web_vitals FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "super_admin read all vitals"
  ON public.perf_web_vitals FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));

CREATE INDEX IF NOT EXISTS idx_perf_web_vitals_metric_created
  ON public.perf_web_vitals (metric, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_perf_web_vitals_route
  ON public.perf_web_vitals (route);
