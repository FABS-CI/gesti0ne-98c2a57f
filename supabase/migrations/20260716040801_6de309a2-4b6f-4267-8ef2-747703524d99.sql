
CREATE TABLE IF NOT EXISTS public.notifications (
  notification_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  titre text NOT NULL,
  message text,
  type_notification text NOT NULL DEFAULT 'info',
  priorite text,
  module text,
  lien text,
  document_type text,
  document_id text,
  document_reference text,
  user_id uuid,
  role_cible text,
  lu boolean NOT NULL DEFAULT false,
  date_notification date NOT NULL DEFAULT current_date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read their notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (
    user_id IS NULL
    OR user_id = auth.uid()
    OR (role_cible IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role::text = notifications.role_cible
    ))
  );

CREATE POLICY "Authenticated insert notifications"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users update their notifications"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (user_id IS NULL OR user_id = auth.uid())
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());

CREATE POLICY "Users delete their notifications"
  ON public.notifications FOR DELETE
  TO authenticated
  USING (user_id IS NULL OR user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_lu ON public.notifications(lu);
CREATE INDEX IF NOT EXISTS idx_notifications_date ON public.notifications(date_notification DESC);

DROP TRIGGER IF EXISTS trg_notifications_updated_at ON public.notifications;
CREATE TRIGGER trg_notifications_updated_at
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Préférences utilisateur
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  modules_desactives text[] NOT NULL DEFAULT '{}',
  types_desactives text[] NOT NULL DEFAULT '{}',
  notifs_navigateur boolean NOT NULL DEFAULT true,
  son_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_preferences TO authenticated;
GRANT ALL ON public.notification_preferences TO service_role;

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own notification prefs"
  ON public.notification_preferences FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP TRIGGER IF EXISTS trg_notification_preferences_updated_at ON public.notification_preferences;
CREATE TRIGGER trg_notification_preferences_updated_at
  BEFORE UPDATE ON public.notification_preferences
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
