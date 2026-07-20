import { useEffect } from "react";
import { useRouter } from "@tanstack/react-router";
import type { QueryClient, QueryKey } from "@tanstack/react-query";

/**
 * Préchargement intelligent au temps mort du navigateur.
 *
 * Router active déjà `defaultPreload: "intent"` (survol/focus), ce qui
 * couvre la navigation au clic. Ce hook complète en pré-chargeant, dès
 * que le thread principal est libre, les routes/queries que l'on sait
 * probablement visitées ensuite (ex. après login : dashboard, notifs,
 * commandes du jour). Utilise `requestIdleCallback` avec fallback
 * `setTimeout` pour ne jamais bloquer un rendu utile.
 *
 * Convention : n'appeler que pour des ressources RÉELLEMENT probables.
 * Un préchargement gratuit reste un aller-retour réseau — pas d'abus
 * type "toutes les routes de l'ERP".
 */

type IdleWindow = Window & {
  requestIdleCallback?: (
    cb: (deadline: { timeRemaining: () => number; didTimeout: boolean }) => void,
    opts?: { timeout: number },
  ) => number;
  cancelIdleCallback?: (id: number) => void;
};

function runIdle(cb: () => void, timeout = 2000): () => void {
  if (typeof window === "undefined") return () => {};
  const w = window as IdleWindow;
  if (typeof w.requestIdleCallback === "function") {
    const id = w.requestIdleCallback(() => cb(), { timeout });
    return () => w.cancelIdleCallback?.(id);
  }
  const id = window.setTimeout(cb, 200);
  return () => window.clearTimeout(id);
}

export interface PrefetchTarget {
  /** Route TanStack à précharger (ex: '/commandes'). */
  route?: string;
  /** QueryKey + fetcher pour warm-up React Query. */
  query?: {
    queryKey: QueryKey;
    queryFn: () => Promise<unknown>;
    staleTime?: number;
  };
}

/**
 * Précharge une liste de cibles pendant les temps morts du navigateur.
 * À appeler dans un layout stable (AppShell) après l'auth.
 */
export function useIdlePrefetch(
  targets: PrefetchTarget[],
  queryClient: QueryClient,
  enabled = true,
) {
  const router = useRouter();
  useEffect(() => {
    if (!enabled || targets.length === 0) return;
    const cancels: Array<() => void> = [];
    for (const t of targets) {
      cancels.push(
        runIdle(() => {
          if (t.route) {
            router.preloadRoute({ to: t.route }).catch(() => {});
          }
          if (t.query) {
            queryClient
              .prefetchQuery({
                queryKey: t.query.queryKey,
                queryFn: t.query.queryFn,
                staleTime: t.query.staleTime ?? 60_000,
              })
              .catch(() => {});
          }
        }),
      );
    }
    return () => cancels.forEach((c) => c());
  }, [router, queryClient, enabled, targets]);
}

/**
 * Précharge une route sur intersection (ex : bouton "voir plus" ou lien
 * en bas de liste virtualisée). Retourne un ref à poser sur l'élément.
 */
export function useViewportPrefetch(route: string, enabled = true) {
  const router = useRouter();
  return (node: HTMLElement | null) => {
    if (!enabled || !node || typeof IntersectionObserver === "undefined") return;
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            router.preloadRoute({ to: route }).catch(() => {});
            io.disconnect();
            break;
          }
        }
      },
      { rootMargin: "200px" },
    );
    io.observe(node);
  };
}
