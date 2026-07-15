
-- Retire l'accès public/anon aux fonctions RBAC (elles restent accessibles aux users connectés)
REVOKE EXECUTE ON FUNCTION public.list_user_permissions(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.has_permission_v2(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assert_permission(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rbac_role_ancestors(uuid) FROM PUBLIC, anon;

-- Resserre la policy INSERT sur rbac_audit_log : seule l'insertion via trigger
-- (SECURITY DEFINER) doit passer. On bloque l'INSERT client direct en exigeant
-- que l'user soit super_admin (les triggers s'exécutent en SECURITY DEFINER
-- sous le owner et ne sont donc pas soumis à cette policy).
DROP POLICY IF EXISTS "rbac_audit insert authenticated" ON public.rbac_audit_log;
CREATE POLICY "rbac_audit insert super_admin only"
  ON public.rbac_audit_log FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));
