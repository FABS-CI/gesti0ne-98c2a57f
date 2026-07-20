-- P2 perf : rétention des audit_logs (>90 jours) via pg_cron.
-- Empêche la croissance non bornée de la table.

CREATE OR REPLACE FUNCTION public.purge_audit_logs_expired()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.audit_logs
  WHERE created_at < now() - interval '90 days';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

-- Extensions cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Supprime l'ancien job s'il existe déjà (idempotent)
DO $$
DECLARE
  v_jobid bigint;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'purge-audit-logs-90d';
  IF v_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_jobid);
  END IF;
END $$;

-- Planifie tous les jours à 03:15 UTC
SELECT cron.schedule(
  'purge-audit-logs-90d',
  '15 3 * * *',
  $$ SELECT public.purge_audit_logs_expired(); $$
);
