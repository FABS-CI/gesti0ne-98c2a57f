# Plan de Refactorisation et d'Optimisation ERP FABS-CI

## Objectifs
- Améliorer la performance globale (TTFB, FCP, LCP).
- Consolider l'architecture technique (TanStack Start, Supabase, RBAC v3).
- Éliminer la dette technique identifiée lors de l'audit v2.2.1.
- Garantir une maintenabilité à long terme et une scalabilité accrue.

## Étapes du Plan

### 1. Optimisation de la Couche de Données et SQL
- **Migration vers `stocks_depots`** : Supprimer définitivement l'usage de `produits.stock` (champ statique) au profit d'une agrégation temps réel ou d'une vue matérialisée basée sur `stocks_depots`.
- **Indexation Trigramme** : Généraliser les index `pg_trgm` sur les colonnes de recherche (clients, produits, références) pour la recherche globale.
- **Nettoyage RBAC** : Supprimer physiquement les tables `user_roles` et `permissions` des versions v1 et v2 pour ne garder que le schéma v3 actif.
- **Optimisation des Politiques RLS** : Refactoriser les politiques RLS complexes pour utiliser des fonctions `security definer` afin d'éviter les récursions et améliorer les temps de réponse.

### 2. Performance Frontend et TanStack Start
- **Pagination Serveur Généralisée** : Implémenter la pagination native TanStack Router sur tous les tableaux (`ProduitsTable`, `ClientsTable`, `CommandesTable`) pour limiter le payload JSON.
- **Stratégie de Cache (Query Keys)** : Affiner les `PERSISTED_QUERY_KEYS` dans `src/routes/__root.tsx` pour inclure uniquement les référentiels critiques et réduire l'usage du localStorage.
- **Code Splitting** : Analyser et découper les gros composants (ex: `CommandeForm`, `UnifiedGenerator`) en sous-composants chargés dynamiquement via `lazy()`.
- **Réduction du Bundle PDF** : Isoler les bibliothèques lourdes comme `pdf-lib` et `qrcode` dans des fonctions serveur ou des imports dynamiques stricts pour ne pas alourdir le FCP.

### 3. Fiabilisation du Moteur PDF (BaseDocument v2)
- **Standardisation des Templates** : Migrer tous les documents restants (Achats, Proforma) vers la classe `BaseDocument` pour assurer une cohérence visuelle (#1B2A57 / #FFF3E0).
- **Gestion des Notes et Annexes** : Implémenter une gestion robuste des sauts de page pour les longs textes de notes/observations afin d'éviter les chevauchements.
- **Isolation des Logic** : Séparer les calculateurs financiers (TVA, Remises mutuellement exclusives) des générateurs de rendu PDF.

### 4. Sécurité et Auditabilité
- **Audit Logs v2** : Étendre le système d'audit pour inclure les métadonnées de performance par action (temps d'exécution côté serveur).
- **MFA Enforcement** : Rendre le MFA obligatoire pour tous les rôles sauf Super Admin, avec une période de grâce configurable.
- **Rotation des Secrets** : Mettre en place une procédure automatisée de rotation des clés d'API (Google Drive, etc.) via le gestionnaire de secrets.

### 5. Consolidation UX/UI (Modern Stack)
- **Design Tokens OKLCH** : Finaliser la migration de tous les composants `ui/*` vers les variables sémantiques définies dans `src/styles.css`.
- **Accessibilité (A11y)** : Audit complet des contrastes et de la navigation au clavier, particulièrement sur les formulaires complexes.
- **Responsive Strict** : Optimiser les vues "Tablette" pour une utilisation fluide en entrepôt (Colisage/Stocks).

## Indicateurs de Succès (KPIs)
- Score Lighthouse Performance > 90 sur mobile.
- Temps de génération PDF < 1.5s pour 10 pages.
- Zéro erreur SQL "N+1" identifiée en audit.
