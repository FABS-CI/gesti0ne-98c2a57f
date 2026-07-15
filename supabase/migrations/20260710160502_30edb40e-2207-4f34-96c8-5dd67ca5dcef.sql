INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'comptable'
  AND p.code IN (
    'dashboard.voir','dashboard_direction.voir','dashboard_metier.voir',
    'dashboard_personnel.voir','mon_dashboard.voir','dashboard_global.voir',
    'clients_dashboard.voir','dashboard_logistique.voir','compta_dashboard.voir',
    'dashboard.voir_alertes','dashboard.voir_objectifs','dashboard.voir_widgets',
    'dashboard.personnaliser','dashboard.voir_ventes','dashboard.voir_achats',
    'dashboard.voir_paiements','dashboard.voir_creances','dashboard.voir_depenses',
    'rapports.voir','rapports.exporter_pdf','rapports.telecharger',
    'rapports_comptables.voir','rapports_logistique.voir'
  )
ON CONFLICT (role_id, permission_code) DO UPDATE SET accorde = true;