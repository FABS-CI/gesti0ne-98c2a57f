-- Aligner les permissions du rôle "assistante_comptable" sur celles du rôle "comptable"
-- afin que l'assistante comptable voie l'ensemble des données de l'entreprise
-- conformément au RBAC.
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT ac.role_id, rp.permission_code, TRUE
FROM public.rbac_roles ac
CROSS JOIN LATERAL (
  SELECT rp.permission_code
  FROM public.rbac_role_permissions rp
  JOIN public.rbac_roles c ON c.role_id = rp.role_id
  WHERE c.code = 'comptable' AND rp.accorde = TRUE
) rp
WHERE ac.code = 'assistante_comptable'
ON CONFLICT (role_id, permission_code)
DO UPDATE SET accorde = TRUE;