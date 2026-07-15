
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS mfa_enrolled_at timestamptz;

CREATE TABLE public.mfa_backup_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_hash text NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_mfa_backup_codes_user ON public.mfa_backup_codes(user_id) WHERE used_at IS NULL;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mfa_backup_codes TO authenticated;
GRANT ALL ON public.mfa_backup_codes TO service_role;
ALTER TABLE public.mfa_backup_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own backup codes" ON public.mfa_backup_codes FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "admin read backup codes" ON public.mfa_backup_codes FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));
CREATE POLICY "admin delete backup codes" ON public.mfa_backup_codes FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.mfa_otp_attempts (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fail_count integer NOT NULL DEFAULT 0,
  locked_until timestamptz,
  last_fail_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mfa_otp_attempts TO authenticated;
GRANT ALL ON public.mfa_otp_attempts TO service_role;
ALTER TABLE public.mfa_otp_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own attempts" ON public.mfa_otp_attempts FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "admin read attempts" ON public.mfa_otp_attempts FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));
CREATE POLICY "admin update attempts" ON public.mfa_otp_attempts FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.mfa_session_validations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_token text NOT NULL,
  validated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '12 hours'),
  revoked_at timestamptz,
  ip_address text,
  user_agent text
);
CREATE INDEX idx_mfa_session_val_user ON public.mfa_session_validations(user_id, session_token) WHERE revoked_at IS NULL;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mfa_session_validations TO authenticated;
GRANT ALL ON public.mfa_session_validations TO service_role;
ALTER TABLE public.mfa_session_validations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own sessions" ON public.mfa_session_validations FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "admin read sessions" ON public.mfa_session_validations FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));
CREATE POLICY "admin revoke sessions" ON public.mfa_session_validations FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));

CREATE OR REPLACE FUNCTION public.mfa_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;
CREATE TRIGGER trg_mfa_otp_attempts_updated
  BEFORE UPDATE ON public.mfa_otp_attempts
  FOR EACH ROW EXECUTE FUNCTION public.mfa_touch_updated_at();
