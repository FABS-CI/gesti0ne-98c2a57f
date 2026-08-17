# Plan de Refactorisation — Étape 3 : RBAC v3 & Dettes Techniques

Ce plan détaille la migration finale vers le moteur de permissions **RBAC v3** et la correction des dettes techniques identifiées lors de l'audit expert.

## Changements

### 🔐 Sécurité & RBAC v3
- **Audit des Gardes UI** : Révision de `src/components/rbac/Can.tsx` pour s'assurer que les permissions v3 (ex: `commandes.creer`) sont privilégiées sur les codes v2, tout en maintenant le pont via `expandRbac3Permissions`.
- **Nettoyage du Catalogue** : Mise à jour de `src/lib/rbac-permission-codes.ts` pour refléter la réalité du terrain et supprimer les doublons inutiles.
- **Transparence Admin** : Vérification stricte de l'exemption de logs/notifications pour le rôle `super_admin`.

### 📦 Données & Performance
- **Optimisation PDF** : Standardisation du rendu des notes et des totaux dans `BaseDocument` pour éviter les chevauchements sur les documents longs.
- **Intégrité Stock** : Finalisation du retrait des références à la colonne `produits.stock` (legacy) au profit de l'agrégation temps réel depuis `stocks_depots`.

### 🛠️ UX & Modernisation
- **Validation Interactive** : Amélioration des retours visuels lors des changements de droits (refresh temps réel).
- **Accessibilité** : Standardisation des polices et contrastes sur les exports PDF professionnels.

## Détails techniques

### RBAC Bridge (`src/lib/rbac3-bridge.ts`)
- Mise à jour des mappings pour inclure les nouveaux modules identifiés durant l'audit.
- Optimisation de la fonction `expandRbac3Permissions` pour réduire la complexité cyclomatique.

### PDF Engine (`src/lib/pdf/base-document.ts`)
- Ajustement du `threshold` de saut de page pour les blocs de signatures.
- Correction du calcul de `maxRowH` pour les textes multi-lignes très longs.

### Hooks & State
- Fix du bug de reset de l'état `loading` dans `NotificationPreferencesPanel.tsx`.
- Synchronisation du cache TanStack Query pour `rbac.permissions` avec un `staleTime` de 15min.

## Questions (facultatif)
*Aucune question bloquante à ce stade.*
