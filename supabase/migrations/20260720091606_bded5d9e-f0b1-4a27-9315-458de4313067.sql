
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_clients_actif_created_at
  ON public.clients (actif, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clients_nom_trgm
  ON public.clients USING gin (nom gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_clients_reference_trgm
  ON public.clients USING gin (reference gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_clients_representant_trgm
  ON public.clients USING gin (representant gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_audit_logs_table_created
  ON public.audit_logs (table_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_incident_alerts_resolved_created
  ON public.incident_alerts (resolved, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_incident_alerts_source
  ON public.incident_alerts (source);

CREATE INDEX IF NOT EXISTS idx_notifications_user_date
  ON public.notifications (user_id, date_notification DESC);

ANALYZE public.clients;
ANALYZE public.audit_logs;
ANALYZE public.incident_alerts;
ANALYZE public.notifications;
