
-- 1) Extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2) read_at column + trigger
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

UPDATE public.notifications SET read_at = updated_at WHERE lu = true AND read_at IS NULL;

CREATE OR REPLACE FUNCTION public.notifications_set_read_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.lu = true AND (OLD.lu IS DISTINCT FROM true) THEN
    NEW.read_at := now();
  ELSIF NEW.lu = false THEN
    NEW.read_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notifications_set_read_at ON public.notifications;
CREATE TRIGGER trg_notifications_set_read_at
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.notifications_set_read_at();

CREATE INDEX IF NOT EXISTS idx_notifications_read_at
  ON public.notifications (read_at) WHERE lu = true;
CREATE INDEX IF NOT EXISTS idx_notifications_unread_created
  ON public.notifications (created_at) WHERE lu = false;

-- 3) Purge log table
CREATE TABLE IF NOT EXISTS public.notifications_purge_log (
  purge_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  executed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_read INT NOT NULL DEFAULT 0,
  deleted_unread INT NOT NULL DEFAULT 0,
  remaining INT NOT NULL DEFAULT 0,
  error TEXT
);

GRANT SELECT ON public.notifications_purge_log TO authenticated;
GRANT ALL ON public.notifications_purge_log TO service_role;

ALTER TABLE public.notifications_purge_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "purge_log_admin_select" ON public.notifications_purge_log;
CREATE POLICY "purge_log_admin_select"
  ON public.notifications_purge_log FOR SELECT
  TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role));

-- 4) Purge function
CREATE OR REPLACE FUNCTION public.purge_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_read INT := 0;
  v_unread INT := 0;
  v_remaining INT := 0;
  v_err TEXT;
BEGIN
  BEGIN
    WITH del AS (
      DELETE FROM public.notifications
      WHERE lu = true AND read_at IS NOT NULL AND read_at < now() - INTERVAL '1 hour'
      RETURNING 1
    )
    SELECT count(*) INTO v_read FROM del;

    WITH del AS (
      DELETE FROM public.notifications
      WHERE lu = false AND created_at < now() - INTERVAL '20 hours'
      RETURNING 1
    )
    SELECT count(*) INTO v_unread FROM del;

    SELECT count(*) INTO v_remaining FROM public.notifications;
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
  END;

  INSERT INTO public.notifications_purge_log(deleted_read, deleted_unread, remaining, error)
  VALUES (v_read, v_unread, v_remaining, v_err);
END;
$$;

REVOKE ALL ON FUNCTION public.purge_notifications() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_notifications() TO service_role;

-- 5) Schedule every 10 minutes
DO $$
BEGIN
  PERFORM cron.unschedule('purge-notifications-10min')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-notifications-10min');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'purge-notifications-10min',
  '*/10 * * * *',
  $$ SELECT public.purge_notifications(); $$
);
