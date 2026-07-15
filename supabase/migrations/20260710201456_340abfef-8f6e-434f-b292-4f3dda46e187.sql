REVOKE EXECUTE ON FUNCTION public.rbac_set_role_permission(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rbac_set_role_permission(uuid, text, boolean) TO authenticated;