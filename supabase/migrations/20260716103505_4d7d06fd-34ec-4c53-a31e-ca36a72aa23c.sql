
-- 1. Restreindre l'accès aux audit_logs au super_admin uniquement
DROP POLICY IF EXISTS audit_logs_admin_read ON public.audit_logs;
CREATE POLICY audit_logs_super_admin_read ON public.audit_logs
  FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));

-- 2. Recréer la vue audit_events avec les colonnes attendues par le front
DROP VIEW IF EXISTS public.audit_events;
CREATE VIEW public.audit_events
WITH (security_invoker = true)
AS
SELECT
  id,
  user_id,
  user_email,
  action,
  module,
  table_name,
  record_id,
  NULL::text AS record_ref,
  created_at AS occurred_at,
  old_values,
  new_values,
  NULL::jsonb AS changes,
  ip_address,
  user_agent,
  NULL::text AS url,
  NULL::text AS http_method,
  NULL::int  AS status,
  NULL::int  AS duration_ms,
  entity_type,
  entity_id,
  details
FROM public.audit_logs;

GRANT SELECT ON public.audit_events TO authenticated;
