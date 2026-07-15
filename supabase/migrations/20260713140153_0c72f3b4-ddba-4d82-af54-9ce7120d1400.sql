
INSERT INTO public.rbac_roles (code, libelle, description, actif, systeme)
VALUES (
  'commercial',
  'Commercial',
  'Peut créer/modifier des clients (sans voir leur solde), consulter les commandes et suivre les livraisons.',
  true,
  false
)
ON CONFLICT (code) DO UPDATE SET libelle = EXCLUDED.libelle, description = EXCLUDED.description, actif = true;

INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'commercial'
  AND p.code IN (
    'clients.voir',
    'clients.creer',
    'clients.modifier',
    'clients.exporter_pdf',
    'clients.imprimer',
    'clients.voir_historique',
    'commandes.voir',
    'commandes.voir_historique',
    'commandes.telecharger_pdf',
    'commandes.exporter_pdf',
    'commandes.imprimer',
    'livraison_suivi.voir',
    'livraison_suivi.voir_historique',
    'bons_livraison.voir',
    'bons_livraison.voir_historique',
    'livraisons.voir'
  )
ON CONFLICT (role_id, permission_code) DO UPDATE SET accorde = true;
