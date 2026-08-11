GRANT EXECUTE ON FUNCTION public.normalize_phone(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_clients_crm(jsonb, integer, integer) TO authenticated, anon;
GRANT ALL ON FUNCTION public.search_clients_crm(jsonb, integer, integer) TO service_role;
GRANT ALL ON FUNCTION public.normalize_phone(text) TO service_role;