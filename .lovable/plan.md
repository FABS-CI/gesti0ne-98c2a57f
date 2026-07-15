## Audit — état du projet

Projet ERP de grande taille (181 routes authentifiées, ~100 tables). L'ossature est saine (TanStack Start + Query, RLS/GRANT en place sur la plupart des tables, root `head()` correct, design tokens sémantiques). Les problèmes se concentrent sur la **cohérence transverse** et le **polish UX**, pas sur l'architecture.

### Constats prioritaires

**Critique (à corriger vite)**
1. **Titres d'onglet** : seul le root définit un `<title>`. Les 181 routes `_authenticated/*` héritent toutes du même titre "EDITIONS FABS-CI — Gestion centralisée de l'entreprise". Résultat : onglets/bookmarks indistinguables, navigation historique cassée.
2. **Pas de `noindex` sur `_authenticated/*`** : l'app métier privée peut être indexée par les moteurs — risque de fuite d'URL et pollution SEO du domaine public.
3. **215 `as any`** dans `src/` — masquent des vraies erreurs de type. Concentrations à identifier (probables : Supabase RPC non typés, formulaires legacy).
4. **31 routes avec `useEffect`** dont ~25 accèdent `supabase.*` directement — probable pattern `useEffect + fetch` au lieu de TanStack Query (perte de cache, race conditions, pas d'invalidation coordonnée).

**Élevé (UX / cohérence)**
5. **États vide / erreur / filtres** — pattern déjà appliqué à 6 écrans (produits, fournisseurs, inventaires, colisage, incidents, spécimens, employés). Reste ~20 index-routes clés sans badges de filtres, sans empty state contextuel, sans `describeSupabaseError` sur les mutations (`achats`, `commandes`, `clients`, `factures`, `paiements`, `livraisons`, `transferts`, `avoirs`, `retours`, `bons-livraison`, `tournees`, `contrats`, `conges`, `absences`, `vehicules`, `depots`, `bulletins-paie`, `evaluations`, `missions`, `documents`).
6. **Composants dupliqués** : les badges de filtres + empty-state ont été copiés/collés sur 6+ écrans. À extraire en `<FilterBadges>` et `<EmptyState>` réutilisables.
7. **Responsive tables** : plusieurs `<Table>` en écrans denses sans `overflow-x-auto` / vue mobile "carte".
8. **Loading states** : plusieurs écrans utilisent `if (!data) return null` (écran blanc) au lieu de `<Skeleton>`.

**Modéré**
9. **`console.log/error`** résiduels (surtout `client-error-tracing`, OK) — vérifier qu'il n'y a pas de logs de debug oubliés.
10. **A11y** : boutons icône-only sans `aria-label` sur les tables (édition/suppression/duplication).
11. **Layout mobile** : `h-screen` au lieu de `h-dvh` sur AppShell — hauteur cassée sur iOS.

**Backend**
12. Lancer `supabase--linter` pour vérifier RLS/policies laxistes sur les 100+ tables (non fait ici, à faire en passe 2).

---

## Plan de correction en 4 passes

### Passe 1 — Critique transverse (cette itération)
- Helper partagé `buildRouteHead(title, opts?)` → titre par route + `noindex` sur tout `_authenticated/*`.
- Composants réutilisables `<FilterBadges>` et `<EmptyState>` (extraits des 6 écrans déjà faits).
- Appliquer titre + noindex aux **20 index-routes clés** en une passe mécanique.

### Passe 2 — États UX manquants
- Étendre le pattern filtres/empty-state/`describeSupabaseError` aux 20 écrans listés au point 5, en utilisant les composants de la passe 1.
- Skeleton loading pour les tables denses.

### Passe 3 — Refactor & typage
- Extraire les tables lourdes (`AchatsTable`, `CommandesTable`, etc.) dans `src/components/<domaine>/list/` si pas déjà fait.
- Réduire `as any` : chasser les 20 plus gros clusters (typage Supabase RPC, form handlers).
- Migrer les `useEffect + supabase` restants vers TanStack Query.

### Passe 4 — Perf, a11y, backend
- `aria-label` sur tous les icon-buttons, `h-dvh`, focus-visible.
- `supabase--linter` + correction des findings RLS/GRANT.
- Lazy-load des routes lourdes (BI, comptabilité, admin.perf).

---

## Sur quoi je démarre maintenant

La passe 1 : je crée le helper `buildRouteHead` + `FilterBadges` + `EmptyState`, puis j'applique titre/noindex + les composants aux ~20 écrans identifiés. Pas de changement de comportement, uniquement métadonnées + extraction de composants.

Tu confirmes ce plan ou tu veux réordonner (par exemple : commencer par la passe 3 refactor, ou par le linter Supabase) ?
