ALTER TABLE public.two_fa_secrets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own MFA secrets" ON public.two_fa_secrets;
CREATE POLICY "Users can manage their own MFA secrets"
ON public.two_fa_secrets
FOR ALL
TO authenticated
USING (auth.uid() = user_id OR public.has_role_compat(auth.uid(), 'super_admin'))
WITH CHECK (auth.uid() = user_id OR public.has_role_compat(auth.uid(), 'super_admin'));

GRANT ALL ON public.two_fa_secrets TO authenticated;
GRANT ALL ON public.two_fa_secrets TO service_role;

ALTER TABLE public.mfa_backup_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read their own backup codes" ON public.mfa_backup_codes;
CREATE POLICY "Users can read their own backup codes"
ON public.mfa_backup_codes
FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR public.has_role_compat(auth.uid(), 'super_admin'));

GRANT ALL ON public.mfa_backup_codes TO authenticated;
GRANT ALL ON public.mfa_backup_codes TO service_role;

DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;
CREATE POLICY "Admins can update all profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (public.has_role_compat(auth.uid(), 'super_admin'));
