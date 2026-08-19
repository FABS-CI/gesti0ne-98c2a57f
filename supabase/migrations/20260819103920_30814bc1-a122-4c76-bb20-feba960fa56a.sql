ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS mfa_required boolean NOT NULL DEFAULT false;
GRANT UPDATE (mfa_required) ON public.profiles TO authenticated;
