REVOKE ALL ON FUNCTION public.trg_guard_profiles_sensitive_fields() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.trg_guard_profiles_sensitive_fields() FROM anon;
REVOKE ALL ON FUNCTION public.trg_guard_profiles_sensitive_fields() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.trg_guard_profiles_sensitive_fields() TO service_role;