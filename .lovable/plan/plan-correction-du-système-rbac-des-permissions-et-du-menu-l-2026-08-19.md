# Plan - Correction du système RBAC, des permissions et du menu latéral

Ce plan vise à corriger le système de contrôle d'accès basé sur les rôles (RBAC) pour garantir que tous les utilisateurs authentifiés, quel que soit leur rôle, accèdent correctement à l'application avec un menu latéral dynamique correspondant à leurs permissions.

## Audit et Diagnostic

1. **Audit de la chaîne d'autorisation** :
    - Vérification du chargement de la session via `useAuth`.
    - Analyse de la récupération des rôles via `useUserRoles` (interroge `rbac3_user_roles` et `rbac3_roles`).
    - Analyse de la récupération des permissions via `usePermissions` (interroge la RPC `rbac3_permissions_of`).
    - Diagnostic du filtrage du menu dans `useVisibleGroups` utilisant `filterNavGroupsByPermissions`.

2. **Identification des points de blocage potentiels** :
    - Problèmes de synchronisation ou de timing lors du chargement initial.
    - Permissions vides (`[]`) interprétées comme un manque d'accès au lieu d'un état de chargement.
    - Incohérences entre les codes de permission v2 (`sous_module.action`) utilisés par l'UI et le moteur v3 (`module.action`) en base.
    - Guards de route (`RouteGuard`) trop restrictifs ou mal synchronisés.

## Actions Techniques

### 1. Sécurisation du chargement des permissions (`src/hooks/use-permissions.ts`)
- S'assurer que `isLoading` reflète correctement l'état d'attente de toutes les sources (Auth, Rôles, Permissions RPC).
- Ajouter des logs de diagnostic pour tracer le flux d'autorisation (ID utilisateur, Rôles détectés, Nombre de permissions).

### 2. Fiabilisation du menu latéral (`src/components/layout/sidebar/use-visible-groups.ts`)
- Empêcher l'affichage d'un menu vide pendant que les permissions sont en cours de chargement.
- S'assurer que les routes "libres" (ex: `/dashboard`, `/profil`) restent visibles pour tous.
- Vérifier que `expandRbacViewPermissions` traite correctement les permissions étendues.

### 3. Correction des Guards de route (`src/components/rbac/RouteGuard.tsx`)
- Aligner la logique d'autorisation du guard sur celle du menu pour éviter qu'un utilisateur voie un lien mais soit bloqué en cliquant dessus (ou inversement).
- S'assurer que les super-admins conservent un accès total via `isSuperAdmin`.

### 4. Vérification et Réparation Backend (Supabase)
- S'assurer que la RPC `rbac3_permissions_of` renvoie les données attendues pour les utilisateurs non-admins.
- Vérifier que les tables `rbac3_user_roles` et `rbac3_role_permissions` sont correctement peuplées et accessibles via l'API (Grants).

## Validation

- Test de connexion avec un compte Administrateur (Menu complet).
- Test de connexion avec un compte non-administrateur (Menu filtré selon ses droits réels).
- Vérification qu'aucune donnée métier n'est modifiée ou supprimée.
- Vérification que l'état de chargement est visible et explicite.

---

## Détails Techniques

- **Source de vérité** : RBAC v3 (tables `rbac3_*`).
- **Pont v3 -> v2** : `src/lib/rbac3-bridge.ts` pour la conversion des codes `module.action` vers `sous_module.action`.
- **Cache** : Utilisation de `staleTime` dans TanStack Query pour limiter les appels RPC tout en conservant le rafraîchissement temps réel via Supabase Realtime.
