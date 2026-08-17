INSERT INTO public.rbac3_role_permissions (role_code, perm_code)
VALUES
  ('admin', 'logistique.supprimer'),
  ('responsable_magasin', 'logistique.supprimer'),
  ('service_logistique', 'logistique.supprimer')
ON CONFLICT DO NOTHING;