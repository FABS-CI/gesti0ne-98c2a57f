GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.has_any_role(uuid, public.app_role[]) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.has_commercial_access(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.has_permission_v2(uuid, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.list_user_permissions(uuid) TO authenticated, anon;