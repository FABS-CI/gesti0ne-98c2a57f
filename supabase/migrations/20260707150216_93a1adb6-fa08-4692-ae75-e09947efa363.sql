
REVOKE ALL ON FUNCTION public.audit_row_change() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.audit_row_change() TO service_role;
