-- Tighten RBAC restored functions and audit policy

REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rbac_role_ancestors(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_user_permissions(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.has_permission_v2(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assert_permission(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rbac_set_role_permission(uuid, text, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rbac_bulk_set_permissions(uuid, text[], boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_permission_denied(text, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_rbac_user_roles_sync_legacy() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_rbac_audit_rp() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_rbac_audit_ur() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_user_permissions(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_user_permissions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_permission_v2(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assert_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rbac_set_role_permission(uuid, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rbac_bulk_set_permissions(uuid, text[], boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_permission_denied(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;

DROP POLICY IF EXISTS "rbac_audit insert authenticated" ON public.rbac_audit_log;
CREATE POLICY "rbac_audit insert authenticated"
  ON public.rbac_audit_log FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);