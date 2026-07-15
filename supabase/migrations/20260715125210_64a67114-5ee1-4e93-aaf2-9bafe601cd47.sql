CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Remove any previous version
DO $$ BEGIN
  PERFORM cron.unschedule('backup-run-schedules-hourly');
EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
  'backup-run-schedules-hourly',
  '5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://project--a3a9a18c-2e2e-4d2a-a5a6-f24efd81bfda.lovable.app/api/public/hooks/run-schedules',
    headers := '{"Content-Type":"application/json","apikey":"sb_publishable_fYx_CRECJhHM6d248U-y8A_XPCRwToH"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);