
-- Lot C : compléter le catalogue RBAC
-- 1) Trésorerie (Finance)
-- 2) Extras Tableau de bord (alertes / objectifs / widgets / personnaliser)
-- 3) Prospects extras (voir contact, convertir en client)

INSERT INTO public.rbac_permissions (code, module, sous_module, action, libelle, description) VALUES
  -- Trésorerie : cartésien voir/creer/modifier/supprimer + spécifiques
  ('tresorerie.voir',              'Finance', 'tresorerie', 'voir',              'Consulter la trésorerie', NULL),
  ('tresorerie.creer',             'Finance', 'tresorerie', 'creer',             'Créer une opération de trésorerie', NULL),
  ('tresorerie.modifier',          'Finance', 'tresorerie', 'modifier',          'Modifier une opération de trésorerie', NULL),
  ('tresorerie.supprimer',         'Finance', 'tresorerie', 'supprimer',         'Supprimer une opération de trésorerie', NULL),
  ('tresorerie.valider',           'Finance', 'tresorerie', 'valider',           'Valider une opération de trésorerie', NULL),
  ('tresorerie.exporter_pdf',      'Finance', 'tresorerie', 'exporter_pdf',      'Exporter la trésorerie en PDF', NULL),
  ('tresorerie.exporter_excel',    'Finance', 'tresorerie', 'exporter_excel',    'Exporter la trésorerie en Excel', NULL),
  ('tresorerie.voir_stats',        'Finance', 'tresorerie', 'voir_stats',        'Voir les statistiques de trésorerie', NULL),
  ('tresorerie.voir_historique',   'Finance', 'tresorerie', 'voir_historique',   'Voir l''historique de trésorerie', NULL),
  -- Dashboard extras
  ('dashboard.voir_alertes',       'Tableau de bord', 'dashboard', 'voir_alertes',   'Voir les alertes du tableau de bord', NULL),
  ('dashboard.voir_objectifs',     'Tableau de bord', 'dashboard', 'voir_objectifs', 'Voir les objectifs', NULL),
  ('dashboard.voir_widgets',       'Tableau de bord', 'dashboard', 'voir_widgets',   'Voir les widgets', NULL),
  ('dashboard.personnaliser',      'Tableau de bord', 'dashboard', 'personnaliser',  'Personnaliser le tableau de bord', NULL),
  ('dashboard.voir_ventes',        'Tableau de bord', 'dashboard', 'voir_ventes',    'Voir les ventes du dashboard', NULL),
  ('dashboard.voir_achats',        'Tableau de bord', 'dashboard', 'voir_achats',    'Voir les achats du dashboard', NULL),
  ('dashboard.voir_paiements',     'Tableau de bord', 'dashboard', 'voir_paiements', 'Voir les paiements du dashboard', NULL),
  ('dashboard.voir_creances',      'Tableau de bord', 'dashboard', 'voir_creances',  'Voir les créances du dashboard', NULL),
  ('dashboard.voir_depenses',      'Tableau de bord', 'dashboard', 'voir_depenses',  'Voir les dépenses du dashboard', NULL),
  -- Prospects extras
  ('prospects.convertir_client',   'Gestion commerciale', 'prospects', 'convertir_client', 'Convertir un prospect en client', NULL),
  ('prospects.voir_contact',       'Gestion commerciale', 'prospects', 'voir_contact',     'Voir les contacts du prospect', NULL)
ON CONFLICT (code) DO NOTHING;
