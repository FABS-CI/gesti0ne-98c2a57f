
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
      WHERE lu = false AND created_at < now() - INTERVAL '2 hours'
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
