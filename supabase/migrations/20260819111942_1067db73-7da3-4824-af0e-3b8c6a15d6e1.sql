-- Assign 'super_admin' role in legacy user_roles (v2)
INSERT INTO public.user_roles (user_id, role)
VALUES ('81ca19d1-bfbe-4611-a8ca-6fe06f63ceaa', 'super_admin')
ON CONFLICT (user_id, role) DO NOTHING;

-- Assign 'super_admin' role in RBAC v3
INSERT INTO public.rbac3_user_roles (user_id, role_code)
VALUES ('81ca19d1-bfbe-4611-a8ca-6fe06f63ceaa', 'super_admin')
ON CONFLICT (user_id, role_code) DO NOTHING;

-- Ensure profile is active and not locked
UPDATE public.profiles
SET 
  actif = true,
  statut = 'actif',
  locked_at = null,
  locked_reason = null,
  mfa_required = false,
  must_change_password = false
WHERE id = '81ca19d1-bfbe-4611-a8ca-6fe06f63ceaa';