
REVOKE EXECUTE ON FUNCTION public.rbac3_assert(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rbac3_scope_service(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rbac3_scope_departement(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rbac3_scope_depot(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rbac3_depots_autorises(uuid) FROM anon;
