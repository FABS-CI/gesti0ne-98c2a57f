
CREATE TABLE IF NOT EXISTS public.user_action_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_key text NOT NULL,
  module text,
  label text,
  icon text,
  href text,
  usage_count integer NOT NULL DEFAULT 0,
  last_used_at timestamptz,
  pinned boolean NOT NULL DEFAULT false,
  hidden boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, action_key)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_action_stats TO authenticated;
GRANT ALL ON public.user_action_stats TO service_role;

ALTER TABLE public.user_action_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_action_stats_select_own"
  ON public.user_action_stats FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_action_stats_insert_own"
  ON public.user_action_stats FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_action_stats_update_own"
  ON public.user_action_stats FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_action_stats_delete_own"
  ON public.user_action_stats FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_user_action_stats_user ON public.user_action_stats(user_id);

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_uas_updated_at ON public.user_action_stats;
CREATE TRIGGER trg_uas_updated_at BEFORE UPDATE ON public.user_action_stats
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.track_user_action(
  _action_key text,
  _module text DEFAULT NULL,
  _label text DEFAULT NULL,
  _icon text DEFAULT NULL,
  _href text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
BEGIN
  IF _uid IS NULL THEN RETURN; END IF;

  INSERT INTO public.user_action_stats (user_id, action_key, module, label, icon, href, usage_count, last_used_at)
  VALUES (_uid, _action_key, _module, _label, _icon, _href, 1, now())
  ON CONFLICT (user_id, action_key) DO UPDATE
  SET usage_count = public.user_action_stats.usage_count + 1,
      last_used_at = now(),
      module = COALESCE(EXCLUDED.module, public.user_action_stats.module),
      label  = COALESCE(EXCLUDED.label,  public.user_action_stats.label),
      icon   = COALESCE(EXCLUDED.icon,   public.user_action_stats.icon),
      href   = COALESCE(EXCLUDED.href,   public.user_action_stats.href);
END; $$;

GRANT EXECUTE ON FUNCTION public.track_user_action(text, text, text, text, text) TO authenticated;
