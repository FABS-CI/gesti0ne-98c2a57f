import { QueryClient } from "@tanstack/react-query";
import { createRouter, ErrorComponent } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";

/**
 * Indicateur de chargement léger affiché pendant la résolution d'une route.
 * Évite le "flash blanc" sans altérer le design des pages.
 */
function RoutePending() {
  return (
    <div className="flex items-center justify-center py-10 text-muted-foreground">
      <div className="h-6 w-6 animate-spin rounded-full border-2 border-current border-t-transparent" />
    </div>
  );
}

export const getRouter = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 5 * 60_000,
        gcTime: 30 * 60_000,
        refetchOnWindowFocus: false,
        refetchOnReconnect: true,
        // true (défaut) : au remontage d'une liste, si le cache a été
        // marqué stale par invalidateQueries (mutation faite depuis une
        // autre route : création BC/BL/Facture/Retour…), Query refetch
        // automatiquement. `false` bloquait ce rafraîchissement, obligeant
        // à un F5 manuel.
        refetchOnMount: true,
        retry: 1,
        retryDelay: (attempt) => Math.min(1000 * 2 ** attempt, 8000),
      },
      mutations: {
        retry: 0,
      },
    },
  });

  const router = createRouter({
    routeTree,
    context: { queryClient },
    scrollRestoration: true,
    defaultPreload: "intent",
    // MUST be 0 avec TanStack Query : laisse Query arbitrer la fraîcheur
    // (staleTime 60 s ci-dessus). Sinon le cache de preload Router masque
    // les invalidations Query après mutations.
    defaultPreloadStaleTime: 0,
    // Évite un rendu SSR du spinner sur les routes code-splittées pendant un
    // cold start/HMR : si le client charge déjà la vraie page, React signale
    // sinon un mismatch d'hydratation et le preview peut rester masqué par
    // l'overlay d'erreur.
    defaultPendingMs: 3000,
    // Les routes protégées utilisent `ssr: false`. Leur fallback est rendu
    // côté serveur, mais ne doit pas être artificiellement maintenu pendant
    // l'hydratation : sinon React reçoit le spinner côté serveur et la vraie
    // page côté client, ce qui peut laisser la preview bloquée sur le fallback.
    defaultPendingMinMs: 0,
    defaultPendingComponent: RoutePending,
    defaultErrorComponent: ErrorComponent,
  });

  return router;
};
