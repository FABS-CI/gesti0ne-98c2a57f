REVOKE ALL ON FUNCTION public.can_write_module(text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_write_module(text[]) TO authenticated, service_role;