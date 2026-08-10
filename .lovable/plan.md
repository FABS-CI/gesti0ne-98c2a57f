# Bilan de Production — ERP FABS-CI

## Objectifs Atteints

- **RBAC v2 (moteur actif)** : sécurité granulaire multi-dépôts opérationnelle.
- **Flux métier** : Commandes, Proformas, Factures et Retours sécurisés.
- **Logistique** : Tournées, Colisage et Stocks synchronisés en temps réel.
- **Documentaire** : Charte orange FABS-CI, mentions (FCFA), et signatures intégrées.
- **Sauvegarde** : Export ZIP et procédure de restauration validée.

## Lots Finalisés

- **Lot 1-3** : Intégrité, Idempotence et Formulaires full-page.
- **Lot 4** : Finitions PDF (Orange, signatures, pagination).
- **Lot 5** : Filtres Approvisionnement combinables.
- **Lot 6** : Proforma (badges) et Notifications Temps Réel.
- **Lot 7** : Runbook de restauration complète.

---

## État réel des couches RBAC (à jour)

| Couche | Statut | Détail |
| --- | --- | --- |
| `user_roles` (v0/v1) | **MORT — supprimable** | 0 référence dans `src/`. Conserver la table le temps d'archiver l'historique des comptes seedés, puis `DROP`. |
| `rbac2_*` (`rbac2_user_roles`, `rbac2_roles`, `rbac2_role_perms`, `rbac2_audit`, …) | **MOTEUR ACTIF — NE PAS SUPPRIMER** | Utilisé dans >10 fichiers, dont le contrôle `super_admin` de `src/routes/auth.tsx`, `users.functions.ts`, `security-roles.functions.ts`, `security-users.functions.ts`, `users-admin.functions.ts`. Sa suppression casserait la connexion et l'administration. |
| `rbac3_*` / `rbac3_scope` | **Couche additionnelle** | Scoping complémentaire, utilisé principalement par `ScopesTabV3.tsx`. Pas encore le moteur principal. |

**Règle :** `rbac2_*` reste la source de vérité des rôles tant que `rbac3` n'a pas
repris l'intégralité de la charge (authentification, gestion des utilisateurs, audit).
Toute suppression de `rbac2_*` avant cette bascule est interdite.

## Sécurité des migrations

Aucun mot de passe en clair dans une migration SQL, même temporaire.
Pour du seed : mot de passe aléatoire non commité + `must_change_password`
et invitation par e-mail. Voir `docs/securite-migrations.md`.

## Prochaines Étapes Logiques (Post-MVP)

1. **Suppression Définitive** : nettoyage de la table legacy `user_roles` uniquement.
2. **Performance** : indexation des colonnes de recherche `reference`.
3. **Analytique** : tableaux de bord financiers.
