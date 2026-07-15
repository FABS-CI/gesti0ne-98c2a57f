INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, v.code, true
FROM public.rbac_roles r
CROSS JOIN (VALUES
  ('dashboard.voir'),
  ('dashboard_personnel.voir'),
  ('mon_dashboard.voir'),
  ('dashboard_global.voir'),
  ('dashboard_direction.voir'),
  ('dashboard_logistique.voir'),
  ('dashboard_metier.voir'),
  ('compta_dashboard.voir'),
  ('clients_dashboard.voir')
) AS v(code)
WHERE r.code = 'comptable'
ON CONFLICT (role_id, permission_code) DO UPDATE SET accorde = true;