
-- 1) Enrichir la table audit_logs
ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS session_id text,
  ADD COLUMN IF NOT EXISTS correlation_id uuid,
  ADD COLUMN IF NOT EXISTS url text,
  ADD COLUMN IF NOT EXISTS http_method text,
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'success',
  ADD COLUMN IF NOT EXISTS status_code integer,
  ADD COLUMN IF NOT EXISTS duration_ms integer,
  ADD COLUMN IF NOT EXISTS error_message text,
  ADD COLUMN IF NOT EXISTS criticite text DEFAULT 'info',
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS country_code text,
  ADD COLUMN IF NOT EXISTS browser text,
  ADD COLUMN IF NOT EXISTS browser_version text,
  ADD COLUMN IF NOT EXISTS os text,
  ADD COLUMN IF NOT EXISTS device text,
  ADD COLUMN IF NOT EXISTS screen_resolution text,
  ADD COLUMN IF NOT EXISTS timezone text;

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_email ON public.audit_logs(user_email);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_module ON public.audit_logs(module);
CREATE INDEX IF NOT EXISTS idx_audit_logs_correlation ON public.audit_logs(correlation_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_session ON public.audit_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_criticite ON public.audit_logs(criticite);
CREATE INDEX IF NOT EXISTS idx_audit_logs_ip ON public.audit_logs(ip_address);

-- 2) Table des alertes de sécurité
CREATE TABLE IF NOT EXISTS public.security_alerts (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  alert_type text NOT NULL,
  criticite text NOT NULL DEFAULT 'warning',
  user_id uuid,
  user_email text,
  ip_address text,
  country text,
  city text,
  message text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  acknowledged_at timestamptz,
  acknowledged_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.security_alerts TO authenticated;
GRANT ALL ON public.security_alerts TO service_role;
ALTER TABLE public.security_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "security_alerts_super_admin_read" ON public.security_alerts;
CREATE POLICY "security_alerts_super_admin_read" ON public.security_alerts
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));

DROP POLICY IF EXISTS "security_alerts_service_write" ON public.security_alerts;
CREATE POLICY "security_alerts_service_write" ON public.security_alerts
  FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));

DROP POLICY IF EXISTS "security_alerts_super_admin_ack" ON public.security_alerts;
CREATE POLICY "security_alerts_super_admin_ack" ON public.security_alerts
  FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));

CREATE INDEX IF NOT EXISTS idx_security_alerts_created ON public.security_alerts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_alerts_unack ON public.security_alerts(acknowledged_at) WHERE acknowledged_at IS NULL;

-- 3) Refonte log_audit_event (drop puis recréation avec plus de paramètres)
DROP FUNCTION IF EXISTS public.log_audit_event(text, text, text, text, text, text, text, integer, jsonb, jsonb, jsonb, text);

CREATE OR REPLACE FUNCTION public.log_audit_event(
  p_action text,
  p_module text DEFAULT NULL,
  p_table_name text DEFAULT NULL,
  p_record_id text DEFAULT NULL,
  p_record_ref text DEFAULT NULL,
  p_status text DEFAULT 'success',
  p_error_message text DEFAULT NULL,
  p_duration_ms integer DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_new_values jsonb DEFAULT NULL,
  p_old_values jsonb DEFAULT NULL,
  p_user_email text DEFAULT NULL,
  p_url text DEFAULT NULL,
  p_http_method text DEFAULT NULL,
  p_ip text DEFAULT NULL,
  p_user_agent text DEFAULT NULL,
  p_session_id text DEFAULT NULL,
  p_correlation_id uuid DEFAULT NULL,
  p_criticite text DEFAULT 'info',
  p_city text DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_country_code text DEFAULT NULL,
  p_browser text DEFAULT NULL,
  p_browser_version text DEFAULT NULL,
  p_os text DEFAULT NULL,
  p_device text DEFAULT NULL,
  p_screen_resolution text DEFAULT NULL,
  p_timezone text DEFAULT NULL,
  p_status_code integer DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_id uuid; v_email text := p_user_email;
BEGIN
  IF v_email IS NULL AND auth.uid() IS NOT NULL THEN
    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  END IF;

  INSERT INTO public.audit_logs(
    user_id, user_email, action, module, table_name, record_id,
    entity_type, entity_id, new_values, old_values, details,
    ip_address, user_agent, url, http_method, status, status_code,
    duration_ms, error_message, criticite, session_id, correlation_id,
    city, country, country_code, browser, browser_version, os, device,
    screen_resolution, timezone
  )
  VALUES (
    auth.uid(), v_email, p_action, p_module, p_table_name, p_record_id,
    p_table_name, p_record_id, p_new_values, p_old_values,
    jsonb_build_object('record_ref', p_record_ref, 'metadata', p_metadata),
    p_ip, p_user_agent, p_url, p_http_method, p_status, p_status_code,
    p_duration_ms, p_error_message, p_criticite, p_session_id, p_correlation_id,
    p_city, p_country, p_country_code, p_browser, p_browser_version, p_os, p_device,
    p_screen_resolution, p_timezone
  )
  RETURNING id INTO v_id;
  RETURN v_id;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END; $$;

GRANT EXECUTE ON FUNCTION public.log_audit_event(
  text, text, text, text, text, text, text, integer, jsonb, jsonb, jsonb,
  text, text, text, text, text, text, uuid, text, text, text, text,
  text, text, text, text, text, text, integer
) TO authenticated;

-- 4) Vue audit_events enrichie
DROP VIEW IF EXISTS public.audit_events;
CREATE VIEW public.audit_events
WITH (security_invoker = true)
AS
SELECT
  a.id,
  a.user_id,
  a.user_email,
  a.action,
  a.module,
  a.table_name,
  a.record_id,
  (a.details->>'record_ref') AS record_ref,
  a.created_at AS occurred_at,
  a.old_values,
  a.new_values,
  NULL::jsonb AS changes,
  a.ip_address,
  a.user_agent,
  a.url,
  a.http_method,
  a.status,
  a.status_code,
  a.duration_ms,
  a.error_message,
  a.criticite,
  a.session_id,
  a.correlation_id,
  a.city,
  a.country,
  a.country_code,
  a.browser,
  a.browser_version,
  a.os,
  a.device,
  a.screen_resolution,
  a.timezone,
  a.entity_type,
  a.entity_id,
  a.details
FROM public.audit_logs a;

GRANT SELECT ON public.audit_events TO authenticated;

-- 5) Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.audit_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.security_alerts;
ALTER TABLE public.audit_logs REPLICA IDENTITY FULL;
ALTER TABLE public.security_alerts REPLICA IDENTITY FULL;

-- 6) Trigger CRUD générique
CREATE OR REPLACE FUNCTION public.audit_crud_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_action text;
  v_old jsonb;
  v_new jsonb;
  v_rec_id text;
  v_ref text;
  v_email text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_action := 'INSERT';
    v_new := to_jsonb(NEW);
    v_old := NULL;
    v_rec_id := (v_new->>'id');
  ELSIF TG_OP = 'UPDATE' THEN
    v_action := 'UPDATE';
    v_new := to_jsonb(NEW);
    v_old := to_jsonb(OLD);
    v_rec_id := (v_new->>'id');
  ELSIF TG_OP = 'DELETE' THEN
    v_action := 'DELETE';
    v_old := to_jsonb(OLD);
    v_new := NULL;
    v_rec_id := (v_old->>'id');
  END IF;

  -- Référence lisible (reference si présente, sinon nom, sinon id)
  v_ref := COALESCE(
    (v_new->>'reference'), (v_old->>'reference'),
    (v_new->>'nom'), (v_old->>'nom'),
    (v_new->>'designation'), (v_old->>'designation'),
    v_rec_id
  );

  IF auth.uid() IS NOT NULL THEN
    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  END IF;

  INSERT INTO public.audit_logs(
    user_id, user_email, action, module, table_name, record_id,
    entity_type, entity_id, old_values, new_values,
    details, status, criticite
  )
  VALUES (
    auth.uid(), v_email, v_action, TG_TABLE_NAME, TG_TABLE_NAME, v_rec_id,
    TG_TABLE_NAME, v_rec_id, v_old, v_new,
    jsonb_build_object('record_ref', v_ref, 'trigger', true),
    'success',
    CASE WHEN TG_OP = 'DELETE' THEN 'warning' ELSE 'info' END
  );

  RETURN COALESCE(NEW, OLD);
EXCEPTION WHEN OTHERS THEN
  RETURN COALESCE(NEW, OLD);
END; $$;

-- 7) Attacher aux tables critiques
DO $$
DECLARE t text;
  tbls text[] := ARRAY[
    'commandes','factures','paiements','clients','produits',
    'livraisons','tournees','employes','colis','user_roles',
    'rbac_user_roles','bons_livraison','achats','depots','specimens'
  ];
BEGIN
  FOREACH t IN ARRAY tbls LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=t) THEN
      EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', 'audit_crud_'||t, t);
      EXECUTE format(
        'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_crud_trigger()',
        'audit_crud_'||t, t
      );
    END IF;
  END LOOP;
END $$;

-- 8) Améliorer audit_stats_v2 pour utiliser vrais compteurs
CREATE OR REPLACE FUNCTION public.audit_stats_v2()
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT jsonb_build_object(
    'today', COALESCE((SELECT count(*) FROM public.audit_logs WHERE created_at >= current_date), 0),
    'week', COALESCE((SELECT count(*) FROM public.audit_logs WHERE created_at >= current_date - 7), 0),
    'month', COALESCE((SELECT count(*) FROM public.audit_logs WHERE created_at >= current_date - 30), 0),
    'active_users_today', COALESCE((SELECT count(DISTINCT user_id) FROM public.audit_logs WHERE created_at >= current_date AND user_id IS NOT NULL), 0),
    'connected_now', COALESCE((SELECT count(DISTINCT user_id) FROM public.audit_logs WHERE created_at >= now() - interval '15 minutes' AND user_id IS NOT NULL), 0),
    'logins', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='LOGIN' AND created_at >= current_date), 0),
    'logouts', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='LOGOUT' AND created_at >= current_date), 0),
    'login_failed', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='LOGIN_FAILED' AND created_at >= current_date), 0),
    'creations', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='INSERT' AND created_at >= current_date), 0),
    'modifications', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='UPDATE' AND created_at >= current_date), 0),
    'suppressions', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='DELETE' AND created_at >= current_date), 0),
    'impressions', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='PRINT' AND created_at >= current_date), 0),
    'exports_pdf', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='EXPORT' AND (details->>'metadata')::jsonb->>'format' = 'pdf' AND created_at >= current_date), 0),
    'exports_excel', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='EXPORT' AND (details->>'metadata')::jsonb->>'format' IN ('xlsx','csv') AND created_at >= current_date), 0),
    'validations', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='VALIDATION' AND created_at >= current_date), 0),
    'annulations', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='ANNULATION' AND created_at >= current_date), 0),
    'system_errors', COALESCE((SELECT count(*) FROM public.audit_logs WHERE status='error' AND created_at >= current_date), 0),
    'security_alerts', COALESCE((SELECT count(*) FROM public.security_alerts WHERE acknowledged_at IS NULL), 0)
  );
$$;
