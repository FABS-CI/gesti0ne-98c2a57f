CREATE OR REPLACE FUNCTION public.list_user_permissions(_user_id uuid)
RETURNS TABLE(permission_code text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH base_permissions AS (
    -- Super administrateur : toutes les permissions existantes.
    SELECT p.code AS permission_code
    FROM public.rbac_permissions p
    WHERE EXISTS (
      SELECT 1
      FROM public.user_roles ur
      WHERE ur.user_id = _user_id
        AND ur.role = 'super_admin'::app_role
    )
    OR EXISTS (
      SELECT 1
      FROM public.rbac_user_roles ur
      JOIN public.rbac_roles r ON r.role_id = ur.role_id
      WHERE ur.user_id = _user_id
        AND r.code = 'super_admin'
        AND r.actif
    )

    UNION

    -- Permissions accordées via rôles RBAC v2, héritage inclus.
    SELECT DISTINCT rp.permission_code
    FROM public.rbac_user_roles ur
    JOIN public.rbac_roles r ON r.role_id = ur.role_id AND r.actif
    JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
    JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
    WHERE ur.user_id = _user_id
      AND rp.accorde = true

    UNION

    -- Rétrocompatibilité : rôles historiques mappés vers les rôles RBAC v2.
    SELECT DISTINCT rp.permission_code
    FROM public.user_roles ur
    JOIN public.rbac_roles r ON r.code = ur.role::text AND r.actif
    JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
    JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
    WHERE ur.user_id = _user_id
      AND rp.accorde = true
  ), expanded_permissions AS (
    SELECT permission_code
    FROM base_permissions

    UNION

    -- Sécurité de lecture : toute action métier accordée sur un sous-module
    -- donne aussi la permission `.voir` du même sous-module pour que le menu
    -- et les gardes de route ne masquent jamais un module autorisé.
    SELECT p_view.code AS permission_code
    FROM base_permissions bp
    JOIN public.rbac_permissions p ON p.code = bp.permission_code
    JOIN public.rbac_permissions p_view
      ON p_view.sous_module = p.sous_module
     AND p_view.action = 'voir'
    WHERE p.sous_module IS NOT NULL
      AND p.action <> 'voir'
  )
  SELECT DISTINCT ep.permission_code
  FROM expanded_permissions ep;
$$;

GRANT EXECUTE ON FUNCTION public.list_user_permissions(uuid) TO authenticated;