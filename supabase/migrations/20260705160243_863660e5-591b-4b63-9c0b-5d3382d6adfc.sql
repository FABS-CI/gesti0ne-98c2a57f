
-- Ajoute les 3 types de tableau de bord (Direction / Métier / Personnel)
-- + une permission spécifique pour l'affichage du Chiffre d'Affaires (CA).

-- 1) Permissions "voir" pour chaque type
INSERT INTO public.rbac_permissions(code, module, sous_module, action, libelle) VALUES
  ('dashboard_direction.voir', 'Tableau de bord', 'dashboard_direction', 'voir', 'Tableau de bord Direction — Consulter'),
  ('dashboard_metier.voir',    'Tableau de bord', 'dashboard_metier',    'voir', 'Tableau de bord Métier — Consulter'),
  ('dashboard_personnel.voir', 'Tableau de bord', 'dashboard_personnel', 'voir', 'Tableau de bord Personnel — Consulter'),
  ('dashboard.voir_ca',        'Tableau de bord', 'dashboard',           'voir_ca', 'Tableau de bord — Voir le Chiffre d''Affaires')
ON CONFLICT (code) DO NOTHING;

-- 2) Attribution par défaut
-- Personnel : tout le monde
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, 'dashboard_personnel.voir', true
FROM public.rbac_roles r
WHERE r.actif = true
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- Métier : tous sauf assistante/secrétariat basique — on ouvre à tous les rôles métiers
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, 'dashboard_metier.voir', true
FROM public.rbac_roles r
WHERE r.code IN ('directeur_general','comptable','directeur_commercial',
                 'gestionnaire_stock','responsable_magasinier','service_logistique',
                 'secretariat','assistante','rh')
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- Direction : DG + Directeur commercial + Comptable
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, 'dashboard_direction.voir', true
FROM public.rbac_roles r
WHERE r.code IN ('directeur_general','comptable','directeur_commercial')
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- CA : réservé à DG, Directeur Commercial, Comptable (Super Admin bypass déjà)
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, 'dashboard.voir_ca', true
FROM public.rbac_roles r
WHERE r.code IN ('directeur_general','comptable','directeur_commercial')
ON CONFLICT (role_id, permission_code) DO NOTHING;
