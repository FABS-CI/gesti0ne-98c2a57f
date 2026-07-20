# Lot 4 — Autosave & gestion de conflits

## Composants livrés

- `src/hooks/use-autosave.ts` — hook générique de sauvegarde de brouillon
  dans `localStorage` avec debounce, restauration au montage et effacement.
- `src/hooks/use-autosave.ts` (`useConflictGuard`) — détecte un conflit
  d'édition concurrente à partir du `updated_at` serveur refetché en
  Realtime (Lot 1) et du timestamp de chargement local.
- `src/components/ui/autosave-indicator.tsx` — badge d'état
  (Sauvegarde… / Enregistré / Restaurer le brouillon).

## Usage recommandé

```tsx
const loadedAt = useMemo(() => Date.now(), [commande?.commande_id]);
const auto = useAutosave({
  storageKey: `commande-draft-${commandeId ?? "new"}`,
  value: form.getValues(),
  enabled: !isSubmitting,
  isEmpty: (v) => !v.client_id && (v.lignes ?? []).length === 0,
});

const conflict = useConflictGuard({
  remoteUpdatedAt: commande?.updated_at,
  loadedAt,
  isDirty: form.formState.isDirty,
});

// dans le JSX
<AutosaveIndicator
  status={auto.status}
  savedAt={auto.savedAt}
  hasDraft={auto.hasDraft}
  onRestore={() => form.reset(auto.restore()!)}
  onDiscard={auto.clear}
/>

// après submit réussi
await mutation.mutateAsync(values);
auto.clear();
```

## Où l'appliquer

**Cibles prioritaires** (formulaires longs, perte = friction) :
- `commandes.nouvelle.tsx` / édition commande
- `proformas.nouvelle.tsx`
- `clients.nouveau.tsx` / édition client
- Fiches employé (RH)
- Notes CRM
- Bulletins de paie (édition manuelle)

## Interdictions strictes

- ❌ **Paiements** (`paiements.nouveau.tsx`) — flux transactionnel.
- ❌ **Validation de commande / facture** — action idempotente serveur.
- ❌ **Retours après validation** — impact stock.
- ❌ **Écritures comptables** — traçabilité SYSCOHADA.

Ces flux passent obligatoirement par une soumission serveur atomique
(RPC) sans brouillon client.

## Conflits

Quand `hasConflict` est vrai :
1. Afficher une modale "Ce document a été modifié par un autre
   utilisateur pendant votre saisie."
2. Deux boutons :
   - **Recharger** → `router.invalidate()` + `form.reset(remote)` (perte
     des modifs locales, mais brouillon conservé dans localStorage).
   - **Écraser** → soumettre quand même (nécessite droit d'admin).

Le Realtime Bus (Lot 1) déclenche déjà le refetch en arrière-plan ;
le conflict guard exploite le `updated_at` mis à jour.
