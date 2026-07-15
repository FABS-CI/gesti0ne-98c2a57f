
-- 1. Seed super_admin role in rbac_roles
INSERT INTO public.rbac_roles (code, libelle, actif)
VALUES ('super_admin', 'Super Administrateur', true)
ON CONFLICT DO NOTHING;

-- Also seed common roles so RBAC dropdowns aren't empty
INSERT INTO public.rbac_roles (code, libelle, actif) VALUES
  ('admin', 'Administrateur', true),
  ('manager', 'Manager', true),
  ('employe', 'Employé', true),
  ('comptable', 'Comptable', true),
  ('commercial', 'Commercial', true),
  ('livreur', 'Livreur', true),
  ('rh', 'Ressources Humaines', true),
  ('caissier', 'Caissier', true),
  ('user', 'Utilisateur', true)
ON CONFLICT DO NOTHING;

-- 2. Assign super_admin (rbac) to every auth user
INSERT INTO public.rbac_user_roles (user_id, rbac_role_id)
SELECT u.id, r.id
FROM auth.users u
CROSS JOIN public.rbac_roles r
WHERE r.code = 'super_admin'
  AND NOT EXISTS (
    SELECT 1 FROM public.rbac_user_roles ur
    WHERE ur.user_id = u.id AND ur.rbac_role_id = r.id
  );

-- 3. Assign super_admin (enum-based user_roles) to every auth user
INSERT INTO public.user_roles (user_id, role)
SELECT u.id, 'super_admin'::app_role
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.user_roles ur
  WHERE ur.user_id = u.id AND ur.role = 'super_admin'::app_role
);
