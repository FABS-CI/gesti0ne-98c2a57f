-- Correction SoD (Séparation des Responsabilités) sur la logistique.
-- Le rôle `service_logistique` doit pouvoir CRÉER des tournées et coûts logistiques,
-- mais pas les VALIDER lui-même. La validation revient à `directeur_commercial`
-- (et bien sûr `super_admin`). Les permissions révoquées ci-dessous restent
-- accordées à ces deux rôles.

DELETE FROM public.rbac_role_permissions
WHERE role_id = (SELECT role_id FROM public.rbac_roles WHERE code = 'service_logistique')
  AND permission_code IN (
    'tournees.valider',
    'tournees.valider_couts',
    'tournees.refuser_couts',
    'tournees.annuler_validation',
    'tournees.cloturer',
    'couts_logistiques.valider'
  );