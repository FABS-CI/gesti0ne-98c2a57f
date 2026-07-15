
CREATE TABLE public.document_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  selected_template text NOT NULL DEFAULT 'classique',
  template_per_type jsonb NOT NULL DEFAULT '{}'::jsonb,
  logo_url text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_settings TO authenticated;
GRANT ALL ON public.document_settings TO service_role;

ALTER TABLE public.document_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users manage own document_settings"
  ON public.document_settings FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE TRIGGER document_settings_set_updated_at
  BEFORE UPDATE ON public.document_settings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
