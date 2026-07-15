
-- Fast rewrite of has_permission_v2: same semantics as list_user_permissions
-- (super_admin, RBAC roles + ancestors, legacy user_roles mapping, and
-- implicit ".voir" from any granted action on the same sous_module), but
-- expressed as short-circuit EXISTS checks so RLS policies stop timing out.
CREATE OR REPLACE FUNCTION public.has_permission_v2(_user_id uuid, _perm text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT
    -- 1) Super admin via legacy user_roles
    EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = _user_id AND ur.role = 'super_admin'::app_role
    )
    -- 2) Super admin via RBAC roles
    OR EXISTS (
      SELECT 1
      FROM public.rbac_user_roles ur
      JOIN public.rbac_roles r ON r.role_id = ur.role_id
      WHERE ur.user_id = _user_id AND r.code = 'super_admin' AND r.actif
    )
    -- 3) Direct grant via RBAC roles (with role ancestors)
    OR EXISTS (
      SELECT 1
      FROM public.rbac_user_roles ur
      JOIN public.rbac_roles r ON r.role_id = ur.role_id AND r.actif
      JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
      JOIN public.rbac_role_permissions rp
        ON rp.role_id = anc.role_id
       AND rp.permission_code = _perm
       AND rp.accorde = true
      WHERE ur.user_id = _user_id
    )
    -- 4) Legacy user_roles mapped to RBAC roles
    OR EXISTS (
      SELECT 1
      FROM public.user_roles ur
      JOIN public.rbac_roles r ON r.code = ur.role::text AND r.actif
      JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
      JOIN public.rbac_role_permissions rp
        ON rp.role_id = anc.role_id
       AND rp.permission_code = _perm
       AND rp.accorde = true
      WHERE ur.user_id = _user_id
    )
    -- 5) Implicit ".voir" propagation: any granted action on the same
    --    sous_module implies the corresponding .voir permission.
    OR (
      split_part(_perm, '.', 2) = 'voir'
      AND EXISTS (
        SELECT 1
        FROM public.rbac_permissions p_view
        JOIN public.rbac_permissions p_any
          ON p_any.sous_module = p_view.sous_module
         AND p_any.sous_module IS NOT NULL
         AND p_any.action <> 'voir'
        JOIN public.rbac_role_permissions rp
          ON rp.permission_code = p_any.code
         AND rp.accorde = true
        JOIN public.rbac_roles r ON r.role_id = rp.role_id AND r.actif
        LEFT JOIN public.rbac_user_roles ur ON ur.role_id = r.role_id AND ur.user_id = _user_id
        LEFT JOIN public.user_roles legacy_ur
          ON legacy_ur.user_id = _user_id
         AND legacy_ur.role::text = r.code
        WHERE p_view.code = _perm
          AND (ur.user_id IS NOT NULL OR legacy_ur.user_id IS NOT NULL)
      )
    );
$function$;

-- Helpful indexes for the hot lookup paths (idempotent).
CREATE INDEX IF NOT EXISTS idx_rbac_user_roles_user ON public.rbac_user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_rbac_user_roles_role ON public.rbac_user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_rbac_role_permissions_role_perm
  ON public.rbac_role_permissions(role_id, permission_code) WHERE accorde;
CREATE INDEX IF NOT EXISTS idx_rbac_role_permissions_perm
  ON public.rbac_role_permissions(permission_code) WHERE accorde;
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON public.user_roles(user_id);
