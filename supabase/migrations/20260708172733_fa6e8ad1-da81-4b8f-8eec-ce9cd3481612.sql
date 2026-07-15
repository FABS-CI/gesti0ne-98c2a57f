INSERT INTO public.rbac_permissions(code, module, sous_module, action, libelle) VALUES
  ('documents.supprimer',        'Documents',            'documents',         'supprimer', 'Documents — Supprimer un fichier'),
  ('livraisons.supprimer',       'Livraisons',           'livraisons',        'supprimer', 'Suivi livraisons — Supprimer un événement'),
  ('modeles_documents.supprimer','Modèles de documents', 'modeles_documents', 'supprimer', 'Modèles de documents — Supprimer un modèle')
ON CONFLICT (code) DO NOTHING;

-- Attributions par défaut
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN (VALUES
  ('documents.supprimer'),
  ('livraisons.supprimer'),
  ('modeles_documents.supprimer')
) AS p(code)
WHERE r.code IN ('super_admin','directeur_general','directeur_commercial')
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, 'documents.supprimer', true
FROM public.rbac_roles r
WHERE r.code = 'comptable'
ON CONFLICT (role_id, permission_code) DO NOTHING;