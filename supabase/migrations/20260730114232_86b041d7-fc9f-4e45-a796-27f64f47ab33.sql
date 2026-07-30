INSERT INTO public.rbac2_user_roles (user_id, role_code)
SELECT ur.user_id, ur.role::text
FROM public.user_roles ur
JOIN public.rbac2_roles r ON r.code = ur.role::text
WHERE NOT EXISTS (
  SELECT 1 FROM public.rbac2_user_roles r2
  WHERE r2.user_id = ur.user_id AND r2.role_code = ur.role::text
)
AND EXISTS (SELECT 1 FROM auth.users u WHERE u.id = ur.user_id)
ON CONFLICT DO NOTHING;