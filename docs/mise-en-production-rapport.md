# Rapport de mise en production — ERP FABS-CI

Date : 2026-07-06
Opération : purge complète des données transactionnelles (option A du plan).

## Données conservées

| Référentiel        | Lignes |
| ------------------ | ------ |
| clients            | 1 071  |
| employes           | 15     |
| produits           | 91     |
| fournisseurs       | 2      |
| depots             | 2      |
| user_roles / rbac_*| intact |
| parametres, FNE, modèles docs, SMTP/SMS/API | intact |

## Tables purgées (RESTART IDENTITY CASCADE)

Cycle commercial : `proformas`, `proforma_lignes`, `commandes`, `commande_lignes`,
`bons_livraison`, `ordres_colisage`, `colis`, `colis_lignes`,
`colis_statut_historique`, `colisage_modifications_historique`, `tournees`,
`livsuivi_tournees`, `livsuivi_commandes`, `livsuivi_historique`, `expeditions`,
`livraisons`, `livraisons_commande`, `livraison_commande_historique`,
`factures`, `fne_factures`, `fne_logs`, `retours`, `retour_lignes`,
`bons_retour`, `paiements`, `paiement_annulations_audit`, `specimens`,
`specimen_lignes`, `client_fidelite_mouvements`.

Achats : `achats`, `achat_lignes`.

Stock : `stock_mouvements`, `stocks_depots`, `inventaires`, `inventaire_lignes`.

Compta / finances : `ecritures_comptables`, `ecriture_lignes`, `transactions`,
`exercice_cloture_journal`, `soldes_ouverture_clients`,
`soldes_ouverture_fournisseurs`, `couts_logistiques`.

Incidents / workflow / techniques : `incidents`, `incident_lignes`,
`incident_alerts`, `workflow_approvals`, `historique_envois`, `documents`,
`notifications`, `notifications_purge_log`, `audit_events`, `audit_logs`,
`login_history`, `perf_query_log`, `trigger_execution_log`.

## Compteurs / numérotation

Toutes les séquences `IDENTITY` des tables purgées ont été remises à 1
(`RESTART IDENTITY`). La numérotation métier (devis, commande, facture, BL,
etc.) est dérivée du `MAX(numero)+1` par année dans le code applicatif : elle
repartira donc automatiquement à 1 sur le premier document de production.

Les soldes matérialisés `clients.solde` et `clients.solde_points` ont été
remis à 0.

## Contrôles d'intégrité

- `TRUNCATE ... CASCADE` a supprimé toutes les références orphelines.
- `ANALYZE` exécuté sur toute la base.
- Aucune FK cassée après purge (vérifié).
- Table `audit_events` : 1 071 lignes réapparues immédiatement — trace
  d'audit de la mise à zéro des soldes clients (comportement normal du
  trigger). Non bloquant.

## Anomalies

Aucune anomalie bloquante. Warnings pré-existants du linter Supabase
(SECURITY DEFINER, search_path) inchangés par la migration — à traiter
séparément si besoin.

## Validation

✅ ERP FABS-CI prêt pour la mise en production.
Recommandations :
1. Vérifier les tableaux de bord (tous à 0 attendu).
2. Créer le premier devis / commande de test réel puis contrôler la
   numérotation.
3. Programmer la première sauvegarde post-production.