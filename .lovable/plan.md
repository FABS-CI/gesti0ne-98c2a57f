# H2 — Découpe des routes monolithiques

## Contexte
3 fichiers dépassent 800 lignes sur des workflows critiques logistique :
- `tournees.$tourneeId.tsx` (948 l.) — édition d'une tournée + colis + coûts + clôture
- `tournees.nouvelle.tsx` (849 l.) — création d'une tournée
- `logistics-costs.tsx` (801 l.) — analyse des coûts logistique

Ces écrans mélangent : types, requêtes Supabase, calculs métier, sous-formulaires, dialogs, tableaux. La règle TanStack (« ne PAS exporter les fonctions composants des fichiers routes ») nous oblige à **extraire les sous-composants dans `src/components/`**, pas dans le fichier route.

## Stratégie sûre
Extraction **conservatrice** : uniquement les blocs autonomes (aucune logique métier modifiée). Objectif : ramener chaque route ≤ 400 lignes, sans toucher aux appels Supabase, ni aux calculs de coûts, ni aux mutations.

## Découpe fichier par fichier

### 1. `tournees.$tourneeId.tsx` (948 → ~380 lignes)
Extraire vers `src/components/tournees/edit/` :
- `tournee-edit-types.ts` — types `Tournee`, `ColisRow`, etc.
- `TourneeInfoCard.tsx` — carte infos générales (ref, date, chauffeur, véhicule, statut)
- `TourneeCoutsCard.tsx` — carte des 6 champs coûts + total calculé
- `TourneeColisTable.tsx` — tableau des colis rattachés + actions
- `TourneeClotureDialog.tsx` — dialog de clôture

### 2. `tournees.nouvelle.tsx` (849 → ~350 lignes)
Extraire vers `src/components/tournees/create/` :
- `tournee-create-types.ts`
- `NewTourneeHeader.tsx` — champs entête (ref, date, chauffeur…)
- `NewTourneeColisPicker.tsx` — sélecteur de colis disponibles
- `NewTourneeCoutsInputs.tsx` — bloc coûts prévisionnels

### 3. `logistics-costs.tsx` (801 → ~350 lignes)
Extraire vers `src/components/logistics-costs/` :
- `logistics-costs-types.ts`
- `CostsFilters.tsx` — filtres période / type / statut
- `CostsKpiCards.tsx` — cartes KPI (total, moyenne, répartition)
- `CostsBreakdownTable.tsx` — tableau détaillé par tournée

## Règles techniques
- **Aucune modification** des requêtes Supabase, RPC, mutations, calculs.
- Passage explicite des props (états + setters) depuis la route parent — pas de contexte, pas de store.
- `Route.useLoaderData` reste dans la route parent uniquement.
- Chaque sous-composant est un `export function` classique dans `src/components/` (l'interdiction d'export ne concerne QUE les fichiers `src/routes/`).
- Vérif après chaque extraction : build Vite OK + navigation manuelle sur l'écran.

## Ordre d'exécution
1. `logistics-costs` (moins critique, read-only) — validation du modèle.
2. `tournees.$tourneeId` (édition, plus risqué).
3. `tournees.nouvelle` (création, écrit en base).

## Estimation
- Étape 1 : ~30 min
- Étape 2 : ~1 h
- Étape 3 : ~45 min
- Total : ~2 h 15

## Livrables
- Score H2 clos, ERP passe à **~92 / 100**.
- Aucun changement fonctionnel — pur refactor de présentation.
- Fichiers routes ramenés sous 400 lignes chacun (seuil recommandé TanStack).

## Ce que ce plan NE fait PAS
- Pas de réécriture de la logique métier.
- Pas de changement de schéma DB.
- Pas de refonte UX — l'écran reste identique pixel pour pixel.
