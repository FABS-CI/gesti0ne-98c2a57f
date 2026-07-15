
-- Nouveau rôle métier : Responsable Logistique (éditable via UI)
INSERT INTO public.rbac_roles (code, libelle, description, actif, systeme)
VALUES (
  'responsable_logistique',
  'Responsable Logistique',
  'Pilote la logistique : tournées, livraisons, suivi, remise au livreur. Droits ajustables depuis Rôles & Permissions.',
  true,
  false
)
ON CONFLICT (code) DO NOTHING;

-- Copie des permissions du rôle système service_logistique
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT
  (SELECT role_id FROM public.rbac_roles WHERE code = 'responsable_logistique'),
  rp.permission_code,
  rp.accorde
FROM public.rbac_role_permissions rp
WHERE rp.role_id = (SELECT role_id FROM public.rbac_roles WHERE code = 'service_logistique')
ON CONFLICT (role_id, permission_code) DO NOTHING;
