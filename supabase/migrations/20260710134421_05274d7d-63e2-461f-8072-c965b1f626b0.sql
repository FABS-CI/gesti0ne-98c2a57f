
CREATE POLICY "employe read own record"
ON public.employes
FOR SELECT
TO authenticated
USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "admin delete otp attempts"
ON public.mfa_otp_attempts
FOR DELETE
TO authenticated
USING (has_role(auth.uid(), 'super_admin'::app_role));
