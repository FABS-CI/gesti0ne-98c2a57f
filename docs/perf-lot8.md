# Lot 8 — Suspense boundaries granulaires + skeletons ciblés

## Objectif

Remplacer les spinners plein écran par des **boundaries locaux** qui
laissent le reste de la page utilisable pendant qu'un bloc charge ses
données, avec des **skeletons ciblés** qui reproduisent la forme finale
(pas de "shift" visuel à l'arrivée du contenu).

## Livrables

- `src/components/ui/skeletons.tsx` : `SkeletonTable`, `SkeletonCards`,
  `SkeletonForm`, `SkeletonKpiRow`, `SkeletonList`.
- `src/components/ui/section.tsx` : `<Section>` — combine `Suspense` +
  `ErrorBoundary` locaux avec bouton "Réessayer" (basé sur
  `react-error-boundary`, installé dans ce lot).

## Utilisation type

```tsx
import { Section } from '@/components/ui/section';
import { SkeletonKpiRow, SkeletonTable } from '@/components/ui/skeletons';

export function DashboardPage() {
  const queryClient = useQueryClient();
  return (
    <div className="space-y-6">
      <Section
        fallback={<SkeletonKpiRow count={4} />}
        onReset={() => queryClient.invalidateQueries({ queryKey: ['dashboard-kpi'] })}
      >
        <KpiCards />
      </Section>

      <Section
        fallback={<SkeletonTable rows={10} cols={6} />}
        onReset={() => queryClient.invalidateQueries({ queryKey: ['ventes-recentes'] })}
      >
        <VentesRecentesTable />
      </Section>
    </div>
  );
}
```

## Règles

- Un `<Section>` **par bloc data-dépendant**, pas par page.
- Les composants enfants doivent utiliser `useSuspenseQuery` — pas
  `useQuery` + `isLoading` (sinon Suspense ne se déclenche jamais).
- Toujours fournir un `fallback` **de la bonne forme** (table → SkeletonTable,
  KPI → SkeletonKpiRow). Éviter le spinner générique dans un `<Section>`.
- `onReset` doit invalider la/les query keys concernées pour que le bouton
  "Réessayer" recharge vraiment.

## Cibles prioritaires (à câbler ensuite)

1. Tableau de bord (KPI + widgets)
2. Fiche client 360 (onglets)
3. Liste factures / commandes (skeleton table pendant chargement d'exercice)
4. Détail colisage / tournée
