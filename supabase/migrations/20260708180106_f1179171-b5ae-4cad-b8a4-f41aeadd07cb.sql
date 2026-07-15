INSERT INTO public.rbac_permissions (code, module, sous_module, action, libelle) VALUES
  ('clients.bloquer',                     'Gestion commerciale', 'clients',              'bloquer',                'Bloquer/débloquer un client'),
  ('commandes.soumettre',                 'Gestion commerciale', 'commandes',            'soumettre',              'Soumettre une commande pour validation'),
  ('commandes.generer_proforma',          'Gestion commerciale', 'commandes',            'generer_proforma',       'Générer une proforma depuis une commande'),
  ('commandes.convertir_en_bl',           'Gestion commerciale', 'commandes',            'convertir_en_bl',        'Convertir une commande en bon de livraison'),
  ('commandes.generer_facture',           'Gestion commerciale', 'commandes',            'generer_facture',        'Générer une facture depuis une commande'),
  ('commandes.telecharger_pdf',           'Gestion commerciale', 'commandes',            'telecharger_pdf',        'Télécharger le PDF d''une commande'),
  ('proformas.convertir_en_commande',     'Gestion commerciale', 'proformas',            'convertir_en_commande',  'Convertir une proforma en commande'),
  ('proformas.telecharger_pdf',           'Gestion commerciale', 'proformas',            'telecharger_pdf',        'Télécharger le PDF d''une proforma'),
  ('factures.soumettre_fne',              'Gestion commerciale', 'factures',             'soumettre_fne',          'Soumettre une facture au FNE'),
  ('bons_livraison.telecharger_pdf',      'Gestion commerciale', 'bons_livraison',       'telecharger_pdf',        'Télécharger le PDF d''un BL'),
  ('colisage.deverrouiller',              'Gestion commerciale', 'colisage',             'deverrouiller',          'Déverrouiller un colisage'),
  ('colisage.imprimer_etiquettes',        'Gestion commerciale', 'colisage',             'imprimer_etiquettes',    'Imprimer les étiquettes de colis'),
  ('etat_compte_clients.recalculer',      'Gestion commerciale', 'etat_compte_clients',  'recalculer',             'Recalculer le solde d''un client'),
  ('stock.creer_mouvement',               'Stocks & logistique', 'stock',                'creer_mouvement',        'Créer un mouvement de stock manuel'),
  ('stock.recalculer',                    'Stocks & logistique', 'stock',                'recalculer',             'Recalculer le stock (global ou produit)'),
  ('stock.voir_audit',                    'Stocks & logistique', 'stock',                'voir_audit',             'Voir l''audit du stock'),
  ('stock.voir_mouvements',               'Stocks & logistique', 'stock',                'voir_mouvements',        'Voir les mouvements d''un produit'),
  ('depots.definir_principal',            'Stocks & logistique', 'depots',               'definir_principal',      'Définir le dépôt principal'),
  ('transferts.executer',                 'Stocks & logistique', 'transferts',           'executer',               'Exécuter un transfert'),
  ('transferts.receptionner',             'Stocks & logistique', 'transferts',           'receptionner',           'Réceptionner un transfert'),
  ('transferts.telecharger_pdf',          'Stocks & logistique', 'transferts',           'telecharger_pdf',        'Télécharger le PDF d''un transfert'),
  ('inventaires.regulariser',             'Stocks & logistique', 'inventaires',          'regulariser',            'Régulariser un inventaire'),
  ('achats.receptionner',                 'Stocks & logistique', 'achats',               'receptionner',           'Réceptionner un achat'),
  ('achats.payer',                        'Stocks & logistique', 'achats',               'payer',                  'Payer un achat'),
  ('tournees.cloturer',                   'Stocks & logistique', 'tournees',             'cloturer',               'Clôturer une tournée'),
  ('tournees.valider_couts',              'Stocks & logistique', 'tournees',             'valider_couts',          'Valider les coûts d''une tournée'),
  ('tournees.refuser_couts',              'Stocks & logistique', 'tournees',             'refuser_couts',          'Refuser les coûts d''une tournée'),
  ('tournees.annuler_validation',         'Stocks & logistique', 'tournees',             'annuler_validation',     'Annuler la validation d''une tournée'),
  ('livraisons.avancer_etape',            'Stocks & logistique', 'livraisons',           'avancer_etape',          'Faire avancer une étape de livraison'),
  ('livraisons.avancer_masse',            'Stocks & logistique', 'livraisons',           'avancer_masse',          'Faire avancer les livraisons en masse'),
  ('livraisons.valider_remise',           'Stocks & logistique', 'livraisons',           'valider_remise',         'Valider une remise de livraison'),
  ('paiements.rejeter',                   'Finance',             'paiements',            'rejeter',                'Rejeter un paiement'),
  ('paiements.imprimer_recu',             'Finance',             'paiements',            'imprimer_recu',          'Imprimer un reçu de paiement'),
  ('paiements.voir_historique_annulations','Finance',            'paiements',            'voir_historique_annulations','Voir l''historique des annulations de paiements'),
  ('fec.generer',                         'Comptabilité',        'fec',                  'generer',                'Générer le fichier FEC'),
  ('exercices.cloturer',                  'Comptabilité',        'exercices',            'cloturer',               'Clôturer un exercice comptable'),
  ('fne.soumettre',                       'Comptabilité',        'fne',                  'soumettre',              'Soumettre une facture au FNE'),
  ('fne.reessayer',                       'Comptabilité',        'fne',                  'reessayer',              'Réessayer un envoi FNE'),
  ('fne.rembourser',                      'Comptabilité',        'fne',                  'rembourser',             'Rembourser via le FNE'),
  ('fne.telecharger_json',                'Comptabilité',        'fne',                  'telecharger_json',       'Télécharger le JSON FNE'),
  ('fne.modifier_parametres',             'Comptabilité',        'fne',                  'modifier_parametres',    'Modifier les paramètres FNE'),
  ('employes.restaurer',                  'Ressources humaines', 'employes',             'restaurer',              'Restaurer un employé archivé'),
  ('employes.renumeroter',                'Ressources humaines', 'employes',             'renumeroter',            'Renuméroter les matricules employés'),
  ('employes.imprimer_fiche',             'Ressources humaines', 'employes',             'imprimer_fiche',         'Imprimer la fiche employé'),
  ('employes.creer_compte',               'Ressources humaines', 'employes',             'creer_compte',           'Créer un compte utilisateur pour un employé'),
  ('conges.approuver',                    'Ressources humaines', 'conges',               'approuver',              'Approuver un congé'),
  ('conges.rejeter',                      'Ressources humaines', 'conges',               'rejeter',                'Rejeter un congé'),
  ('paie.creer_bulletin',                 'Paie',                'paie',                 'creer_bulletin',         'Créer un bulletin de paie'),
  ('paie.modifier_bulletin',              'Paie',                'paie',                 'modifier_bulletin',      'Modifier un bulletin de paie'),
  ('paie.supprimer_bulletin',             'Paie',                'paie',                 'supprimer_bulletin',     'Supprimer un bulletin de paie'),
  ('paie.imprimer_bulletin',              'Paie',                'paie',                 'imprimer_bulletin',      'Imprimer un bulletin de paie'),
  ('paie.declarer_cnps',                  'Paie',                'paie',                 'declarer_cnps',          'Déclarer la CNPS'),
  ('paie.declarer_fdfp',                  'Paie',                'paie',                 'declarer_fdfp',          'Déclarer le FDFP'),
  ('paie.declarer_its',                   'Paie',                'paie',                 'declarer_its',           'Déclarer l''ITS'),
  ('paie.telecharger_declaration',        'Paie',                'paie',                 'telecharger_declaration','Télécharger une déclaration paie'),
  ('notifications.marquer_lue',           'Notifications',       'notifications',        'marquer_lue',            'Marquer une notification comme lue'),
  ('notifications.purger',                'Notifications',       'notifications',        'purger',                 'Purger les notifications'),
  ('notifications.generer',               'Notifications',       'notifications',        'generer',                'Générer des notifications'),
  ('notifications.exporter_historique',   'Notifications',       'historique_envois',    'exporter_historique',    'Exporter l''historique des envois'),
  ('backup.exporter_csv',                 'Administration',      'backup',               'exporter_csv',           'Exporter une sauvegarde en CSV'),
  ('backup.planifier',                    'Administration',      'backup',               'planifier',              'Planifier une sauvegarde'),
  ('backup.restaurer',                    'Administration',      'backup',               'restaurer',              'Restaurer une sauvegarde'),
  ('utilisateurs.activer_desactiver',     'Administration',      'utilisateurs',         'activer_desactiver',     'Activer / désactiver un utilisateur'),
  ('utilisateurs.assigner_role',          'Administration',      'utilisateurs',         'assigner_role',          'Assigner un rôle à un utilisateur'),
  ('utilisateurs.revoquer_role',          'Administration',      'utilisateurs',         'revoquer_role',          'Révoquer un rôle d''un utilisateur'),
  ('utilisateurs.reset_mfa',              'Administration',      'utilisateurs',         'reset_mfa',              'Réinitialiser le MFA d''un utilisateur'),
  ('utilisateurs.revoquer_mfa',           'Administration',      'utilisateurs',         'revoquer_mfa',           'Révoquer le MFA d''un utilisateur'),
  ('roles_permissions.creer_role',        'Administration',      'roles_permissions',    'creer_role',             'Créer un rôle'),
  ('roles_permissions.modifier_role',     'Administration',      'roles_permissions',    'modifier_role',          'Modifier un rôle'),
  ('roles_permissions.supprimer_role',    'Administration',      'roles_permissions',    'supprimer_role',         'Supprimer un rôle'),
  ('roles_permissions.dupliquer_role',    'Administration',      'roles_permissions',    'dupliquer_role',         'Dupliquer un rôle'),
  ('roles_permissions.assigner_permission','Administration',     'roles_permissions',    'assigner_permission',    'Modifier les permissions d''un rôle'),
  ('roles_permissions.assigner_role_utilisateur','Administration','roles_permissions',   'assigner_role_utilisateur','Assigner un rôle à un utilisateur'),
  ('roles_permissions.voir_audit',        'Administration',      'roles_permissions',    'voir_audit',             'Voir l''audit RBAC'),
  ('audit.recalculer_soldes',             'Administration',      'audit',                'recalculer_soldes',      'Recalculer les soldes clients globaux')
ON CONFLICT (code) DO NOTHING;

-- super_admin : toutes les nouvelles permissions
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'super_admin'
  AND p.code IN (
    'clients.bloquer','commandes.soumettre','commandes.generer_proforma','commandes.convertir_en_bl',
    'commandes.generer_facture','commandes.telecharger_pdf','proformas.convertir_en_commande',
    'proformas.telecharger_pdf','factures.soumettre_fne','bons_livraison.telecharger_pdf',
    'colisage.deverrouiller','colisage.imprimer_etiquettes','etat_compte_clients.recalculer',
    'stock.creer_mouvement','stock.recalculer','stock.voir_audit','stock.voir_mouvements',
    'depots.definir_principal','transferts.executer','transferts.receptionner','transferts.telecharger_pdf',
    'inventaires.regulariser','achats.receptionner','achats.payer','tournees.cloturer',
    'tournees.valider_couts','tournees.refuser_couts','tournees.annuler_validation',
    'livraisons.avancer_etape','livraisons.avancer_masse','livraisons.valider_remise',
    'paiements.rejeter','paiements.imprimer_recu','paiements.voir_historique_annulations',
    'fec.generer','exercices.cloturer','fne.soumettre','fne.reessayer','fne.rembourser',
    'fne.telecharger_json','fne.modifier_parametres','employes.restaurer','employes.renumeroter',
    'employes.imprimer_fiche','employes.creer_compte','conges.approuver','conges.rejeter',
    'paie.creer_bulletin','paie.modifier_bulletin','paie.supprimer_bulletin','paie.imprimer_bulletin',
    'paie.declarer_cnps','paie.declarer_fdfp','paie.declarer_its','paie.telecharger_declaration',
    'notifications.marquer_lue','notifications.purger','notifications.generer','notifications.exporter_historique',
    'backup.exporter_csv','backup.planifier','backup.restaurer','utilisateurs.activer_desactiver',
    'utilisateurs.assigner_role','utilisateurs.revoquer_role','utilisateurs.reset_mfa','utilisateurs.revoquer_mfa',
    'roles_permissions.creer_role','roles_permissions.modifier_role','roles_permissions.supprimer_role',
    'roles_permissions.dupliquer_role','roles_permissions.assigner_permission',
    'roles_permissions.assigner_role_utilisateur','roles_permissions.voir_audit','audit.recalculer_soldes'
  )
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- directeur_general : tout sauf admin critique
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'directeur_general'
  AND p.code IN (
    'clients.bloquer','commandes.soumettre','commandes.generer_proforma','commandes.convertir_en_bl',
    'commandes.generer_facture','commandes.telecharger_pdf','proformas.convertir_en_commande',
    'proformas.telecharger_pdf','factures.soumettre_fne','bons_livraison.telecharger_pdf',
    'colisage.imprimer_etiquettes','etat_compte_clients.recalculer',
    'stock.voir_audit','stock.voir_mouvements','transferts.executer','transferts.receptionner',
    'transferts.telecharger_pdf','inventaires.regulariser','achats.receptionner','achats.payer',
    'tournees.cloturer','tournees.valider_couts','tournees.refuser_couts',
    'livraisons.avancer_etape','livraisons.valider_remise',
    'paiements.rejeter','paiements.imprimer_recu','paiements.voir_historique_annulations',
    'fec.generer','exercices.cloturer','fne.soumettre','fne.reessayer','fne.rembourser',
    'fne.telecharger_json','conges.approuver','conges.rejeter',
    'paie.creer_bulletin','paie.modifier_bulletin','paie.imprimer_bulletin',
    'paie.declarer_cnps','paie.declarer_fdfp','paie.declarer_its','paie.telecharger_declaration',
    'notifications.marquer_lue'
  )
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- comptable : finance/compta/paie/déclarations
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'comptable'
  AND p.code IN (
    'etat_compte_clients.recalculer','paiements.rejeter','paiements.imprimer_recu',
    'paiements.voir_historique_annulations','fec.generer','exercices.cloturer',
    'fne.soumettre','fne.reessayer','fne.rembourser','fne.telecharger_json','fne.modifier_parametres',
    'paie.creer_bulletin','paie.modifier_bulletin','paie.supprimer_bulletin','paie.imprimer_bulletin',
    'paie.declarer_cnps','paie.declarer_fdfp','paie.declarer_its','paie.telecharger_declaration',
    'notifications.marquer_lue'
  )
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- directeur_commercial
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'directeur_commercial'
  AND p.code IN (
    'clients.bloquer','commandes.soumettre','commandes.generer_proforma','commandes.convertir_en_bl',
    'commandes.generer_facture','commandes.telecharger_pdf','proformas.convertir_en_commande',
    'proformas.telecharger_pdf','bons_livraison.telecharger_pdf','colisage.imprimer_etiquettes',
    'notifications.marquer_lue'
  )
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- gestionnaire_stock / responsable_magasinier
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code IN ('gestionnaire_stock','responsable_magasinier')
  AND p.code IN (
    'stock.creer_mouvement','stock.voir_audit','stock.voir_mouvements',
    'transferts.executer','transferts.receptionner','transferts.telecharger_pdf',
    'inventaires.regulariser','achats.receptionner','colisage.deverrouiller','colisage.imprimer_etiquettes',
    'notifications.marquer_lue'
  )
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- responsable_logistique / service_logistique
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code IN ('responsable_logistique','service_logistique')
  AND p.code IN (
    'tournees.cloturer','tournees.valider_couts','tournees.refuser_couts',
    'livraisons.avancer_etape','livraisons.avancer_masse','livraisons.valider_remise',
    'transferts.telecharger_pdf','bons_livraison.telecharger_pdf','notifications.marquer_lue'
  )
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- rh
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'rh'
  AND p.code IN (
    'employes.restaurer','employes.renumeroter','employes.imprimer_fiche','employes.creer_compte',
    'conges.approuver','conges.rejeter','paie.imprimer_bulletin','notifications.marquer_lue'
  )
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- assistante / secretariat / assistante_comptable : consultation basique
INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code IN ('assistante','secretariat','assistante_comptable')
  AND p.code IN (
    'notifications.marquer_lue','commandes.telecharger_pdf','proformas.telecharger_pdf',
    'bons_livraison.telecharger_pdf'
  )
ON CONFLICT (role_id, permission_code) DO NOTHING;