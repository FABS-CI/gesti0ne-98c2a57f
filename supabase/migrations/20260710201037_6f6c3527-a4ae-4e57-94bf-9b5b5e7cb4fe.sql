-- RBAC hardening — zero downtime, zero rights loss
-- 1) Keep only the specialized RBAC audit triggers on RBAC tables.
--    The generic audit triggers duplicate entries/events and do not carry the RBAC-specific payload.
DROP TRIGGER IF EXISTS trg_audit_rbac_roles ON public.rbac_roles;
DROP TRIGGER IF EXISTS trg_audit_rbac_role_permissions ON public.rbac_role_permissions;
DROP TRIGGER IF EXISTS trg_audit_rbac_user_roles ON public.rbac_user_roles;

-- 2) Allow authenticated users to read the labels of roles assigned to themselves.
--    This is additive and does not grant write access or access to unassigned roles.
DROP POLICY IF EXISTS "rbac_roles self read" ON public.rbac_roles;
CREATE POLICY "rbac_roles self read"
ON public.rbac_roles
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.rbac_user_roles ur
    WHERE ur.role_id = rbac_roles.role_id
      AND ur.user_id = auth.uid()
  )
);