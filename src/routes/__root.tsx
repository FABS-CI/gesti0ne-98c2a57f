import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  ClientOnly,
  Outlet,
  Link,
  createRootRouteWithContext,
  useRouter,
  HeadContent,
  Scripts,
} from "@tanstack/react-router";
import { lazy, Suspense, useEffect, useState, type ReactNode } from "react";

import appCss from "../styles.css?url";
import { reportLovableError } from "../lib/lovable-error-reporting";
import {
  getClientSessionId,
  installClientErrorTracing,
  newClientErrorId,
  readServerRequestId,
} from "../lib/client-error-tracing";
import { persistQueryClient } from "@tanstack/react-query-persist-client";
import { createSyncStoragePersister } from "@tanstack/query-sync-storage-persister";

const AppActionTracker = lazy(() =>
  import("@/components/AppActionTracker").then((m) => ({ default: m.AppActionTracker })),
);
const PdfPreviewHost = lazy(() =>
  import("@/components/pdf/PdfPreviewHost").then((m) => ({ default: m.PdfPreviewHost })),
);
const Toaster = lazy(() => import("@/components/ui/sonner").then((m) => ({ default: m.Toaster })));

// Overlay de diagnostic perf, monté au niveau root pour être disponible
// sur toutes les routes (auth incluse). Chunk chargé uniquement si activé.
const PerfOverlay = lazy(() =>
  import("@/components/debug/PerfOverlay").then((m) => ({ default: m.PerfOverlay })),
);

function usePerfOverlayEnabled() {
  const [enabled, setEnabled] = useState(false);
  useEffect(() => {
    if (typeof window === "undefined") return;
    const check = () =>
      localStorage.getItem("perfOverlay") === "1" ||
      new URLSearchParams(window.location.search).get("debug") === "perf";
    setEnabled(check());
    const onKey = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.shiftKey && (e.key === "P" || e.key === "p")) {
        e.preventDefault();
        setEnabled((v) => {
          const next = !v;
          try {
            localStorage.setItem("perfOverlay", next ? "1" : "0");
          } catch {
            /* ignore */
          }
          return next;
        });
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
  return enabled;
}

/**
 * Clés de requêtes persistées en localStorage — référentiels partagés lus par
 * de multiples écrans. Faute de Redis serveur disponible sur cette plateforme,
 * cette persistance client tient lieu de cache warm : les données restent
 * disponibles instantanément entre sessions/onglets, même hors ligne, et
 * évitent des refetch coûteux à froid quand le trafic augmente.
 */
const PERSISTED_QUERY_KEYS = new Set([
  "clients-mini",
  "produits-mini",
  "depots",
  "categories-produits",
  "fournisseurs-mini",
  "employes-mini",
  "exercices",
  "parametres",
  "rbac-roles",
  "rbac-permissions",
  "modeles-documents",
]);

function NotFoundComponent() {
  return (
    <div className="flex min-h-dvh items-center justify-center bg-background px-4">
      <div className="max-w-md text-center">
        <h1 className="text-7xl font-bold text-foreground">404</h1>
        <h2 className="mt-4 text-xl font-semibold text-foreground">Page not found</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          The page you're looking for doesn't exist or has been moved.
        </p>
        <div className="mt-6">
          <Link
            to="/"
            className="inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            Go home
          </Link>
        </div>
      </div>
    </div>
  );
}

function ErrorComponent({ error, reset }: { error: Error; reset: () => void }) {
  const router = useRouter();
  const [ids] = useState(() => ({
    clientErrorId: newClientErrorId(),
    clientSessionId: getClientSessionId(),
    serverRequestId: readServerRequestId(),
  }));
  const traceId = ids.serverRequestId ?? ids.clientErrorId;
  // eslint-disable-next-line no-console
  console.error(
    `[client:${ids.clientSessionId}:${ids.clientErrorId}] ` +
      (ids.serverRequestId ? `server=${ids.serverRequestId} ` : "") +
      `route error ->`,
    error,
  );
  useEffect(() => {
    reportLovableError(error, {
      boundary: "tanstack_root_error_component",
      clientSessionId: ids.clientSessionId,
      clientErrorId: ids.clientErrorId,
      serverRequestId: ids.serverRequestId,
    });
  }, [error, ids]);

  return (
    <div className="flex min-h-dvh items-center justify-center bg-background px-4">
      <div className="max-w-md text-center">
        <h1 className="text-xl font-semibold tracking-tight text-foreground">
          This page didn't load
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Something went wrong on our end. You can try refreshing or head back home.
        </p>
        <p className="mt-3 text-xs text-muted-foreground">
          Trace ID:{" "}
          <code className="select-all rounded bg-muted px-1.5 py-0.5 font-mono text-[11px] text-foreground">
            {traceId}
          </code>
        </p>
        <div className="mt-6 flex flex-wrap justify-center gap-2">
          <button
            onClick={() => {
              router.invalidate();
              reset();
            }}
            className="inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            Try again
          </button>
          <a
            href="/"
            className="inline-flex items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
          >
            Go home
          </a>
        </div>
      </div>
    </div>
  );
}

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title: "EDITIONS FABS-CI — Gestion centralisée de l'entreprise" },
      {
        name: "description",
        content:
          "EDITIONS FABS-CI",
      },
      { name: "author", content: "EDITIONS FABS-CI" },
      { property: "og:title", content: "EDITIONS FABS-CI — Gestion centralisée de l'entreprise" },
      {
        property: "og:description",
        content:
          "EDITIONS FABS-CI",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
      { name: "theme-color", content: "#0a2540" },
      { name: "apple-mobile-web-app-capable", content: "yes" },
      { name: "apple-mobile-web-app-title", content: "FABS-CI" },
      { name: "twitter:title", content: "EDITIONS FABS-CI — Gestion centralisée de l'entreprise" },
      {
        name: "description",
        content:
          "EDITIONS FABS-CI",
      },
      {
        property: "og:description",
        content:
          "EDITIONS FABS-CI",
      },
      {
        name: "twitter:description",
        content:
          "EDITIONS FABS-CI",
      },
      {
        property: "og:image",
        content:
          "https://pub-bb2e103a32db4e198524a2e9ed8f35b4.r2.dev/e94d7835-8522-41f4-baa6-159e8abf8e52/id-preview-c8f97523--5799396b-bcb4-415d-acfc-8d2121c67bf8.lovable.app-1783322815611.png",
      },
      {
        name: "twitter:image",
        content:
          "https://pub-bb2e103a32db4e198524a2e9ed8f35b4.r2.dev/e94d7835-8522-41f4-baa6-159e8abf8e52/id-preview-c8f97523--5799396b-bcb4-415d-acfc-8d2121c67bf8.lovable.app-1783322815611.png",
      },
    ],
    links: [
      {
        rel: "stylesheet",
        href: appCss,
      },
      { rel: "icon", type: "image/x-icon", href: "/favicon.ico?v=3" },
      { rel: "icon", type: "image/x-icon", sizes: "32x32", href: "/favicon.ico?v=3" },
      { rel: "icon", type: "image/x-icon", sizes: "16x16", href: "/favicon.ico?v=3" },
      { rel: "apple-touch-icon", sizes: "180x180", href: "/apple-touch-icon.png?v=3" },
      { rel: "manifest", href: "/manifest.webmanifest?v=3" },
    ],
  }),
  shellComponent: RootShell,
  component: RootComponent,
  notFoundComponent: NotFoundComponent,
  errorComponent: ErrorComponent,
});

function RootShell({ children }: { children: ReactNode }) {
  return (
    <html lang="fr">
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}

function RootComponent() {
  const { queryClient } = Route.useRouteContext();
  const perfOverlayEnabled = usePerfOverlayEnabled();

  useEffect(() => {
    installClientErrorTracing();
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const persister = createSyncStoragePersister({
      storage: window.localStorage,
      key: "fabs-query-cache",
      throttleTime: 1000,
    });
    const [unsubscribe] = persistQueryClient({
      queryClient,
      persister,
      maxAge: 24 * 60 * 60 * 1000, // 24 h
      dehydrateOptions: {
        shouldDehydrateQuery: (query) => {
          const first = query.queryKey?.[0];
          return typeof first === "string" && PERSISTED_QUERY_KEYS.has(first);
        },
      },
    });
    return () => unsubscribe();
  }, [queryClient]);

  return (
    <QueryClientProvider client={queryClient}>
      {/* Required: nested routes render here. Removing <Outlet /> breaks all child routes. */}
      <Outlet />
      <ClientOnly fallback={null}>
        <Suspense fallback={null}>
          <AppActionTracker />
          <PdfPreviewHost />
          <Toaster />
        </Suspense>
      </ClientOnly>
      {perfOverlayEnabled && (
        <Suspense fallback={null}>
          <PerfOverlay />
        </Suspense>
      )}
    </QueryClientProvider>
  );
}
