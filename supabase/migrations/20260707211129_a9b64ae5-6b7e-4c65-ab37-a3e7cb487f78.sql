INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
JOIN (
  VALUES
    ('directeur_general', 'commandes.voir'),
    ('directeur_general', 'commandes.modifier'),
    ('directeur_commercial', 'commandes.voir'),
    ('directeur_commercial', 'commandes.creer'),
    ('directeur_commercial', 'commandes.modifier'),
    ('responsable_magasinier', 'commandes.voir')
) AS wanted(role_code, permission_code)
  ON wanted.role_code = r.code
JOIN public.rbac_permissions p
  ON p.code = wanted.permission_code
WHERE r.actif = true
ON CONFLICT (role_id, permission_code)
DO UPDATE SET accorde = true;