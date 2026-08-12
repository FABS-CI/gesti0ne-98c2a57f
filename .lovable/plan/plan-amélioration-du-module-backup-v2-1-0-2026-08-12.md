# Plan — Amélioration du Module Backup (v2.1.0)

Audit et mise à niveau du module de sauvegarde pour introduire la traçabilité par projet, l'historique propre et la gestion dynamique des prochaines exécutions, tout en préservant l'intégrité de l'ERP existant.

## Phase 1 : Audit et Préparation
- [ ] Analyser `src/lib/backup-orchestrator.server.ts` et `src/lib/global-backup.server.ts` pour identifier les points d'injection du `project_id`.
- [ ] Vérifier la table `projects` existante pour mapper les slugs et IDs.
- [ ] Créer une sauvegarde de sécurité de la table `backups` actuelle.

## Phase 2 : Schéma de Données
- [ ] Migration SQL :
    - [ ] Ajouter `project_id` (UUID), `project_name` (Text), `trigger_type` (Enum: AUTOMATIC, MANUAL) à la table `backups`.
    - [ ] Ajouter `completed_at` (Timestamp) et `error_message` (Text).
    - [ ] Créer une vue ou fonction pour le calcul dynamique de la prochaine exécution (Date dernière réussite + 3h).
- [ ] Aligner les politiques RLS.

## Phase 3 : Backend et Orchestration
- [ ] Mettre à jour `orchestrateBackup` :
    - [ ] Gérer le paramètre `project_id` optionnel.
    - [ ] Générer le nom de fichier selon le format `backup_{slug}_{datetime}.zip`.
    - [ ] Implémenter le cycle de vie : `RUNNING` -> `SUCCESS`/`FAILED`.
- [ ] Mettre à jour `buildGlobalArchive` pour supporter l'extraction ciblée par projet si nécessaire (ou marquer comme GLOBAL).

## Phase 4 : Frontend (BackupPage)
- [ ] Refonte de l'interface :
    - [ ] Remplacer les cartes statiques par des données dynamiques (Prochaine exécution, Dernière sauvegarde).
    - [ ] Ajouter les filtres (Projet, Type, Statut, Date).
    - [ ] Mettre à jour le tableau de l'historique avec les colonnes Projet, Type et Actions sécurisées.
- [ ] Implémenter les dialogues de confirmation pour la restauration et la suppression.

## Phase 5 : Nettoyage et Validation
- [ ] Script de nettoyage contrôlé pour les anciens enregistrements d'historique.
- [ ] Tests de bout en bout : Manuel, Automatique (simulé), Multi-projets, Échec.

## Détails techniques
- **Base de données** : Table `public.backups`.
- **Stockage** : Google Drive (via `connector-gateway`) + Local (`/tmp/backups`).
- **Sécurité** : `has_role_compat(auth.uid(), 'super_admin')`.
- **Format Fichier** : `backup_global_YYYYMMDD_HHmmss.zip`.
