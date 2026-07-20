# Lot 7 — Préchargement intelligent des routes

## Objectif

Éliminer la latence perçue au premier clic sur une route probable (dashboard, commandes, factures, clients, stock) en pré-chargeant les chunks JS pendant les temps morts du navigateur.

## Livrables

- `src/hooks/use-idle-prefetch.ts` :
  - `useIdlePrefetch(targets, queryClient, enabled)` : précharge routes + queries via `requestIdleCallback` (fallback `setTimeout`).
  - `useViewportPrefetch(route)` : ref à poser sur un élément — précharge dès qu'il devient visible (IntersectionObserver, `rootMargin: 200px`).
- `AppShell.tsx` : câblage du prefetch idle après login pour les 5 routes majeures (tableau de bord, commandes, factures, clients, stock).

## Baseline déjà en place

Router utilise `defaultPreload: "intent"` (précharge sur hover/focus des `<Link>`) — Lot 7 le complète pour les tout premiers clics avant qu'un lien ait été survolé.

## Règles

- Ne pas précharger plus de 5-6 cibles à la fois : chaque précharge = 1 requête réseau.
- Ne jamais précharger de mutations ou de RPC coûteuses (`ensureQueryData` OK, `prefetchQuery` OK ; pas d'effet de bord).
- Pour listes virtualisées : ajouter `useViewportPrefetch('/route')` sur le dernier élément visible.
