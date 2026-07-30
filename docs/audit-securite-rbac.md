# Rapport d'audit — Moteur de sécurité ERP FABS-CI

Date : 2026-07-27. Étape 1 du chantier « Reconstruction du moteur de sécurité ».
**Aucune modification n'a été effectuée.**

## 1. Tables de sécurité en base

Trois générations de RBAC coexistent :

| Génération | Tables | Volume | État |
|---|---|---|---|
| v0 (enum) | `user_roles` (enum `app_role`, 10 valeurs) | 11 lignes | Encore lu par `has_role()` — utilisé par **toutes** les policies RLS d'administration |
| v1 (legacy) | `rbac_roles` (18), `rbac_permissions` (277), `rbac_role_permissions`, `rbac_user_roles` (14), `rbac_audit_log` | actif | **Doublon** de v2, encore écrit par `users-admin.functions.ts` et lu par `use-user-roles.ts` |
| v2 (courant) | `rbac2_domains`, `rbac2_modules`, `rbac2_resources`, `rbac2_permissions` (331), `rbac2_roles` (18), `rbac2_role_perms` (1158), `rbac2_role_parents`, `rbac2_perm_deps`, `rbac2_user_roles` (14), `rbac2_audit` (1190) | actif | Modèle cible, mais non exclusif |

Autres : `profiles` (14), `departements`, `depots`, `audit_logs`, `rbac_audit_log`, `rbac2_audit`.

### Constat majeur
La source de vérité est **triplée**. Un rôle peut être accordé dans `user_roles` sans l'être dans `rbac2_user_roles` (et inversement), ce qui produit des écarts UI / RLS silencieux. Un trigger `trg_rbac_user_roles_sync_legacy` tente de compenser — mécanisme fragile.

## 2. Politiques RLS

- 224 policies sur le schéma `public`.
- **33** seulement s'appuient sur `has_permission…` (matrice RBAC).
- **100** policies ont `USING (true)` — soit ~45 % des tables sont ouvertes à tout utilisateur authentifié, la sécurité reposant uniquement sur les RPC `SECURITY DEFINER` et l'UI.
- Les policies d'administration RBAC utilisent `has_role(auth.uid(),'super_admin'::app_role)` → dépendent de la table **v0** `user_roles`, pas de `rbac2_user_roles`.

### Conflits identifiés
1. `USING (true)` massif : un utilisateur authentifié peut lire (et parfois écrire) directement via l'API des données hors de son périmètre.
2. Aucune notion de **périmètre** (service / dépôt / département) : `profiles` ne possède ni `service_id`, ni `depot_id`, ni `departement_id` (seulement un champ texte libre `departement`). La règle « seul le Super Admin est global » n'est donc **applicable nulle part** aujourd'hui.
3. Deux fonctions de résolution de permissions parallèles : `has_permission` / `has_permission_v2`, `list_user_permissions` / `list_user_permissions_v2`.

## 3. Fonctions / RPC liées aux droits

`has_role`, `has_any_role`, `has_permission`, `has_permission_v2`, `assert_permission`, `list_user_permissions`, `list_user_permissions_v2`, `log_permission_denied`, `rbac_bulk_set_permissions`, `rbac_set_role_permission`, `rbac_role_ancestors`, `sync_rbac_matrix`, `rbac2_sync_catalog`, `rbac2_diagnose`, `rbac2_list_rpcs`, `rbac2_deps_transitive`, `rbac2_audit_search`, `rbac2_audit_trigger`, `trg_check_sod_roles`, `trg_rbac_audit_rp`, `trg_rbac_audit_ur`, `trg_rbac_user_roles_sync_legacy`, `_notifier_role`.

→ 23 objets, dont **9 en doublon v1/v2**.

## 4. Code applicatif

| Fichier | Lignes | Rôle |
|---|---|---|
| `src/components/roles-permissions/*` (11 fichiers) | 2 810 | Console RBAC (Users, Roles, Matrix, Audit, Sync) |
| `src/lib/rbac-api.ts` | 372 | Accès RPC RBAC v2 |
| `src/lib/rbac-catalog.ts` | 358 | Catalogue statique modules/actions |
| `src/lib/route-permissions.ts` | 235 | Mapping route → permission (189 routes) |
| `src/lib/rbac-menu-diagnostics.ts`, `rbac-permission-codes.ts`, `rbac-permission-normalize.ts`, `roles-permissions-helpers.ts`, `permissions.ts` | ~400 | Utilitaires, dont règles **codées en dur** |
| `src/hooks/use-permissions.ts`, `use-user-roles.ts`, `use-roles-permissions.ts` | 597 | Hooks |
| `src/components/rbac/*` | — | `RouteGuard`, `Can`, `ActifGate` |
| `src/lib/users-admin.functions.ts` | — | CRUD utilisateurs, **écrit encore en v1** |

### Dette technique / règles en dur (contraires à l'objectif « aucune permission codée en dur »)
- `src/lib/permissions.ts` : `USER_RESTRICTIONS` (blocage par **adresse e-mail**) et `READ_ONLY_MATRIX` (lecture seule codée pour `directeur_commercial`).
- `use-visible-groups.ts` : `superAdminOnly` codé dans `nav-data.ts`.
- `scripts/check-rbac-coverage.mjs` : liste blanche de 11 permissions « intentionnellement sans route ».
- `dashboard-landing.ts` : ordre de priorité des dashboards codé en dur.

## 5. Rôles et permissions

18 rôles v2. **6 rôles sans aucun utilisateur** : `auditeur`, `caissier`, `employe`, `livreur`, `manager`, `rh` (233 attributions de permissions inutilisées).
**44 permissions orphelines** (aucun rôle ne les porte) sur 331.
Rôles demandés manquants ou mal nommés : `rh` existe mais sans utilisateur, `assistante` ≠ `secretariat` (doublon fonctionnel), pas de rôle `administrateur` système (`admin` non `is_system`).

## 6. Synthèse des risques

| # | Risque | Gravité |
|---|---|---|
| R1 | 3 sources de vérité pour les rôles → écarts UI/RLS | Critique |
| R2 | 100 policies `USING (true)` → données lisibles hors périmètre | Critique |
| R3 | Aucune donnée de périmètre (service/dépôt) sur l'utilisateur | Critique |
| R4 | Doublons de fonctions v1/v2 → comportement non déterministe | Élevé |
| R5 | Règles d'accès codées en dur (email, read-only, menu) | Élevé |
| R6 | Champs utilisateur manquants (photo, matricule, statut verrouillé, dernière connexion) | Moyen |
| R7 | 6 rôles et 44 permissions inutilisés | Faible |

## 7. Recommandation pour l'étape 2 (suppression contrôlée)

À supprimer : tout le socle **v0 + v1** (`user_roles`, `rbac_*`), les fonctions doublons, la console RBAC actuelle (11 composants), `permissions.ts`, `rbac-catalog.ts`, `roles-permissions-helpers.ts`, les 3 hooks.
À conserver : `rbac2_audit` + `rbac_audit_log` (historiques, append-only), `profiles`, `auth.users`, toutes les données métier, `route-permissions.ts` (à régénérer, pas à jeter).

Migration préalable obligatoire : réécrire les **224 policies** qui référencent `has_role(...,'app_role')` avant de supprimer `user_roles`, sinon perte totale d'accès.

---

## Étape R4 — Unification des sources de vérité des rôles (fait)

- Trigger `trg_rbac_user_roles_propagate` sur `rbac_user_roles` : toute attribution/retrait est propagée automatiquement vers `rbac2_user_roles` (par `code`) et vers `user_roles` (enum `app_role`, encore utilisé par `has_role()` dans les policies RLS). Backfill effectué.
- `use-user-roles.ts` lit désormais `rbac2_user_roles` (tous les rôles v2 actifs) + `user_roles`, au lieu de ne récupérer que `super_admin` depuis v1. Realtime déplacé sur `rbac2_user_roles`.
- Effet : plus d'écart silencieux UI / RLS entre les trois registres, quel que soit le chemin d'écriture (console RBAC, `users-admin.functions.ts`, SQL direct).

---

## Étape R4-bis — Synchronisation bidirectionnelle des registres (2026-07-30)

- Nouveau trigger `trg_rbac2_user_roles_propagate` sur `rbac2_user_roles` :
  toute attribution/retrait effectué côté RBAC v2 (console `/admin/roles-v2`,
  `security-users.functions.ts`, SQL direct) est répercuté sur `user_roles`
  (v0), encore lu par `has_role()` dans les policies RLS.
- Les codes v2 absents de l'enum `app_role` (`admin`, `commercial`, `rh`) sont
  ignorés sans erreur.
- Combiné au trigger existant `trg_rbac_user_roles_propagate` (v1 → v2 → v0),
  la synchronisation est désormais **bidirectionnelle** : plus aucun écart
  possible quel que soit le chemin d'écriture.
- Backfill effectué. Vérification : **0** rôle v2 non propagé en v0.

Reste : suppression physique des socles v0/v1 (`user_roles`, `rbac_*`) et de
la console RBAC legacy `src/components/roles-permissions/*`, qui impose de
réécrire au préalable les policies RLS référençant `has_role(..., app_role)`.

## Lot R4-bis — Retrait des socles RBAC legacy (exécuté)

- **Étape 1** : `has_role_compat(uuid, text)` créée — lit uniquement `rbac2_user_roles` (rôles actifs).
- **Étape 2** : 45 policies RLS réécrites automatiquement, `has_role(..., app_role)` → `has_role_compat(..., 'super_admin')`. Compteur `has_role(` dans `pg_policies` = **0**.
- **Étape 3** : frontend/serveur basculés sur le registre v2 (`use-user-roles`, `auth.tsx`, `users.functions`, `users-admin.functions`, `employe-account.functions`, appels RPC `has_role` → `has_role_compat`). Backfill v0 → v2 : 3 super_admins alignés.
- **Étape 4** : `EXECUTE` sur `has_role(uuid, app_role)` révoqué pour `authenticated`/`anon`/`PUBLIC` (conservé pour `service_role`). Tables `user_roles` / `rbac_*` conservées en filet de sécurité.
- **Étape 5 (non exécutée)** : suppression physique des tables legacy et de l'enum `app_role`, après période d'observation.

Tests : 145/145 unitaires OK.
