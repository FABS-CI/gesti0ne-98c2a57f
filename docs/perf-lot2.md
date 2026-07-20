# Lot 2 — Performance : optimistic updates + virtualisation

## Primitives livrées

### 1. `useOptimisticListMutation` — `src/hooks/use-optimistic-list-mutation.ts`

Helper générique pour mutations de listes avec :
- Snapshot + rollback automatique en cas d'erreur.
- Mise à jour immédiate du cache React Query (ressenti < 300 ms).
- Invalidation post-serveur pour couvrir les tables non-realtime.
- Toast d'erreur configurable.

**Usage recommandé** : suppression de notifications, toggle statut, réordonnancement.

**À NE PAS utiliser sur** : paiements, factures, écritures comptables, mouvements de stock
→ ces mutations sont transactionnelles côté serveur (RPC SECURITY DEFINER),
   un rollback UI peut masquer un état incohérent. Garder la mutation classique
   avec invalidation après confirmation serveur.

### 2. `VirtualList` — `src/components/ui/virtual-list.tsx`

Composant de liste virtualisée basé sur `@tanstack/react-virtual`.
Ne rend que les items visibles → scroll fluide à 10 000+ lignes.

**Contraintes** :
- Hauteur fixe obligatoire.
- `estimateSize` réaliste (sinon recalculs à chaque scroll).
- Ne pas utiliser sur listes paginées serveur (< 100 items par page → aucun gain).

## Ce qui n'a PAS été fait — et pourquoi

- **Réécriture des DataTables existantes** (Audit, Clients, Commandes) :
  déjà paginées serveur + rows memoized. Virtualisation apporterait un gain
  marginal contre un risque élevé de casse (sticky header, tri, scroll horizontal).
- **Optimistic updates sur mutations financières** : risque d'incohérence
  visuelle vs état réel après échec transactionnel. Le Realtime bus (Lot 1)
  suffit à donner un ressenti quasi-instantané multi-utilisateurs.

## Adoption progressive

Migrer une mutation à la fois :
1. Repérer un `useMutation` sur suppression/toggle d'une liste.
2. Remplacer par `useOptimisticListMutation`.
3. Tester le happy path + un scénario d'erreur (rollback visible).
