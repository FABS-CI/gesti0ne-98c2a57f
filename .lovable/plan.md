# Plan de Correction - Système RBAC, Permissions et Menu Latéral

## Problématique
Correction du chargement asynchrone des permissions RBAC v3 pour éviter que le menu latéral ne s'affiche vide pour les utilisateurs non-administrateurs alors qu'ils disposent de droits.

## Actions Techniques

### 1. Sécurisation du Hook de Permissions
- Optimiser `src/hooks/use-permissions.ts` pour garantir que `isLoading` reflète fidèlement l'état de toute la chaîne (Auth -> Rôles -> RPC Permissions).
- S'assurer que `permissions` ne bascule pas sur un `Set` vide prématurément.

### 2. Fiabilisation du Menu Latéral
- Mettre à jour `src/components/layout/sidebar/use-visible-groups.ts` pour bloquer strictement le rendu si `isLoading` est vrai.
- Ajouter des logs de diagnostic pour tracer le nombre de groupes filtrés vs total.

### 3. Synchronisation du Guard de Route
- Aligner `src/components/rbac/RouteGuard.tsx` sur la même logique de chargement pour éviter les redirections vers "Accès Refusé" pendant le chargement des droits.

### 4. Vérification et Diagnostic
- Utiliser Playwright pour simuler un utilisateur non-admin et vérifier la présence des éléments du menu après chargement.
- Valider la persistance des données métier lors de ces opérations de maintenance système.

## Détails Techniques
- **Hook** : `usePermissions` concatène `authLoading`, `rolesLoading` et `query.isLoading`.
- **Pont v3** : `expandRbac3Permissions` convertit les permissions granulaires `module.action` en codes UI `sous_module.voir`.
- **Fichiers impactés** :
    - `src/hooks/use-permissions.ts`
    - `src/components/layout/sidebar/use-visible-groups.ts`
    - `src/components/rbac/RouteGuard.tsx`
