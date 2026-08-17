CREATE OR REPLACE VIEW public.rbac3_user_permissions AS
SELECT DISTINCT
    ur.user_id,
    rp.perm_code as permission_code
FROM public.rbac3_user_roles ur
JOIN public.rbac3_role_permissions rp ON ur.role_code = rp.role_code;

GRANT SELECT ON public.rbac3_user_permissions TO authenticated, anon;
