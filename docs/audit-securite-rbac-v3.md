# Rapport d'audit — Moteur de sécurité ERP FABS-CI (Étape 1)

Date : 2026-07-30. Aucune suppression effectuée à ce stade.

## 1. Socles de sécurité en base

Trois registres de rôles coexistent :

| Socle | Tables | Volumétrie | Statut |
|---|---|---|---|
| v0 (legacy) | `user_roles`, enum `app_role` | 12 lignes | gelé (EXECUTE `has_role` révoqué), alimenté par trigger depuis v2 |
| v1 (legacy) | `rbac_roles`, `rbac_permissions`, `rbac_role_permissions`, `rbac_user_roles`, `rbac_audit_log` | 18 rôles / 277 perms / 14 affectations | **plus lu par l'application** — dette morte |
| v2 (actif) | `rbac2_domains`, `rbac2_modules`, `rbac2_resources`, `rbac2_permissions`, `rbac2_perm_deps`, `rbac2_roles`, `rbac2_role_parents`, `rbac2_role_perms`, `rbac2_user_roles`, `rbac2_audit` | 16 domaines / 60 modules / 137 ressources / 331 permissions / 13 rôles / 1129 attributions / 16 affectations | source de vérité |

## 2. Rôles v2 (tous `actif`)

super_admin (331 perms, 3 users), directeur_general (143, 1), directeur_commercial (118, 1),
admin (115, 1), comptable (64, 1), rh (63, **0 user**), service_logistique (62, 1),
responsable_magasinier (61, 1), commercial (51, 3), assistante_comptable (41, 1),
gestionnaire_stock (36, 1), assistante (23, 1), secretariat (21, 1).

Conforme à la liste cible de l'Étape 5 (13 rôles). `rbac2_role_parents` est **vide** : l'héritage
existe en schéma mais n'est pas utilisé.

## 3. Permissions

- 331 permissions, **0 orpheline** (toutes rattachées à au moins un rôle).
- **43 permissions ne sont accordées qu'au super_admin** (candidates à revue métier).
- 86 codes d'action distincts, dont un noyau normalisé (`voir`, `creer`, `modifier`,
  `supprimer`, `valider`, `annuler`, `imprimer`, `exporter_*`) et une longue traîne
  de ~60 actions spécifiques à une seule ressource (`declarer_cnps`, `renumeroter`,
  `avancer_masse`…). Hétérogénéité à normaliser sur la grille de l'Étape 7.
- Doublons fonctionnels : `exporter`, `exporter_pdf`, `exporter_excel`, `exporter_csv`,
  `telecharger`, `telecharger_pdf`, `telecharger_json`, `exporter_historique`.

## 4. Policies RLS (240 policies, schéma public)

- 49 policies basées sur `has_permission_v2()` → conformes.
- 45 policies basées sur `has_role_compat()` (pont vers v2) → fonctionnelles mais rôle-centrées.
- **49 policies totalement permissives** (`USING (true)` / `WITH CHECK (true)`) : sécurité
  déléguée aux RPC `SECURITY DEFINER`. Risque si un accès Data API direct contourne les RPC.
- **15 policies seulement portent un filtre de périmètre** (`depot_id` / `service_id`).

## 5. Périmètre (Étape 8) — principal écart

- `profiles.service_id` renseigné pour **1 utilisateur sur 14**.
- `user_depots` contient **1 ligne** au total.
- Conséquence : la règle « seul le Super Administrateur a une portée globale » **n'est pas
  appliquée** aujourd'hui ; les autres rôles voient tous les dépôts et services.

## 6. Surfaces applicatives liées aux droits

Moteur / bibliothèques : `src/lib/rbac-api.ts`, `rbac-catalog.ts`, `rbac-menu-diagnostics.ts`,
`rbac-permission-codes.ts`, `rbac-permission-normalize.ts`, `roles-permissions-helpers.ts`,
`route-permissions.ts`, `security-roles.functions.ts`, `security-users.functions.ts`,
`users.functions.ts`, `users-admin.functions.ts`.

Hooks : `use-permissions.ts`, `use-user-roles.ts`, `use-roles-permissions.ts`,
`use-route-restrictions.ts`.

Gardes : `components/rbac/RouteGuard.tsx`, `Can.tsx`, `ActifGate.tsx`,
`layout/sidebar/use-visible-groups.ts`.

UI d'administration — **doublons confirmés** :

| Écran | Route | Base | Verdict |
|---|---|---|---|
| Console RBAC v2 (Users/Roles/Matrice/Audit) | `/admin/roles-v2` | v2 | à conserver |
| RolesAdmin (ancienne console) | `/roles-permissions` | mixte | doublon |
| SecurityDashboard | `/admin/securite` | mixte | à refondre en tableau de bord Étape 11 |
| UsersAdmin | `/utilisateurs` | v2 | fusionner avec la console |
| UserForm / UserFormDialog | `/utilisateurs/nouveau`, `$userId/modifier` | v2 | deux implémentations du même formulaire |

`use-route-restrictions.ts` (liste `profiles.route_restrictions`) est un mécanisme parallèle
au RBAC, non couvert par la matrice — dette technique.

## 7. Synthèse des dettes

1. Trois registres de rôles à réduire à un seul (v1 totalement mort).
2. 49 policies permissives + 45 policies rôle-centrées à basculer en permission + périmètre.
3. Périmètre service/dépôt non alimenté ni appliqué.
4. Duplication des consoles d'administration (3 écrans pour la même fonction).
5. Taxonomie d'actions non normalisée (86 codes, doublons d'export).
6. Héritage de rôles (`rbac2_role_parents`) inutilisé.
7. Mécanisme parallèle `route_restrictions` hors matrice.

## 8. Recommandation

Le schéma v2 correspond déjà au modèle cible **Utilisateur → Rôle → Permissions** de l'Étape 3.
Une reconstruction complète depuis zéro détruirait 1129 attributions correctes et 4432 lignes
d'audit sans gain de modèle. La voie recommandée est une **refonte sur socle v2** :
suppression des socles v0/v1 et des écrans doublons, normalisation des actions, mise en place
réelle du périmètre en RLS, puis refonte UI (console unique + matrice + tableau de bord).
