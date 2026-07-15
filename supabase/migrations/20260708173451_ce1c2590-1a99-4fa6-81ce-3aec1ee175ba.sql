-- Purge des permissions générées pour sous-modules obsolètes
-- Les affectations dans rbac_role_permissions sont supprimées via FK CASCADE (si présente)
-- Sinon suppression explicite avant.
DELETE FROM public.rbac_role_permissions
WHERE permission_code IN (
  SELECT code FROM public.rbac_permissions
  WHERE sous_module IN (
    'paie_dashboard','paie_declarations','paie_generation',
    'paie_exports','paie_rapports','paie_historique','rh_dashboard'
  )
);

DELETE FROM public.rbac_permissions
WHERE sous_module IN (
  'paie_dashboard','paie_declarations','paie_generation',
  'paie_exports','paie_rapports','paie_historique','rh_dashboard'
);