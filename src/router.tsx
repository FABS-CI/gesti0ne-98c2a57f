import { QueryClient } from "@tanstack/react-query";
import { createRouter } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";
import { RouteError, RouteNotFound } from "./components/route-boundaries";

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
    // Ne pas définir de fallback pending global ici. Lors d'un cold start,
    // le serveur peut encore résoudre un chunk alors que le navigateur l'a
    // déjà chargé ; un spinner SSR produit alors un HTML différent du premier
    // rendu client et déclenche une erreur d'hydratation dans la preview.
    defaultErrorComponent: RouteError,
    defaultNotFoundComponent: RouteNotFound,
  });


  return router;
};
