-- Migration pour supprimer totalement le système MFA

-- 1. Supprimer les tables liées au MFA
DROP TABLE IF EXISTS public.mfa_session_validations CASCADE;
DROP TABLE IF EXISTS public.mfa_otp_attempts CASCADE;
DROP TABLE IF EXISTS public.mfa_backup_codes CASCADE;
DROP TABLE IF EXISTS public.two_fa_secrets CASCADE;

-- 2. Supprimer les colonnes liées au MFA dans profiles
ALTER TABLE public.profiles DROP COLUMN IF EXISTS mfa_required;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS mfa_enrolled_at;

-- 3. Supprimer les fonctions et triggers associés
DROP FUNCTION IF EXISTS public.check_mfa_session CASCADE;
DROP FUNCTION IF EXISTS public.check_mfa_requirement CASCADE;