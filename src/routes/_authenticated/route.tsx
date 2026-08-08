import { createFileRoute, isRedirect, Outlet, redirect, retainSearchParams } from "@tanstack/react-router";
import { zodValidator, fallback } from "@tanstack/zod-adapter";
import { z } from "zod";
import { supabase } from "@/integrations/supabase/client";
import { AppShell } from "@/components/layout/AppShell";
import { RouteGuard } from "@/components/rbac/RouteGuard";
import { MfaGate } from "@/components/mfa/MfaGate";
import { ActifGate } from "@/components/rbac/ActifGate";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

// NB: pas de `z.enum()` ici — un enum fermé dans validateSearch peut faire
// throw en SSR au lieu de retomber sur le fallback (cf. TanStack search-params
// guidance). On valide comme string libre et on clamp côté composant.
const layoutSearchSchema = z.object({
  periode: z.string().or(z.number()).optional().catch("30"),
});

export const Route = createFileRoute("/_authenticated")({
  ssr: false,
  validateSearch: zodValidator(layoutSearchSchema),
  search: {
    middlewares: [retainSearchParams(["periode"])],
  },
  // Do NOT cache the auth check: getSession() is a synchronous localStorage
  // read, and caching a stale "no session" result across a sign-in causes a
  // redirect loop between /auth and /dashboard.
  beforeLoad: async () => {
    // ssr:false still evaluates beforeLoad on the server for shell/redirect
    // resolution. Skip the auth check server-side to avoid touching the
    // Supabase client during SSR (which can throw in CF Worker cold-starts).
    if (typeof window === "undefined") return {};
    // Use getSession() (local, synchronous read from storage) instead of
    // getUser() (network round-trip to Supabase Auth). The Supabase client
    // handles token refresh in the background; every protected server call
    // still re-validates the bearer token server-side via requireSupabaseAuth.
    try {
      const { data, error } = await supabase.auth.getSession();
      if (error || !data.session?.user) throw redirect({ to: "/auth" });
      return { user: data.session.user };
    } catch (error) {
      if (isRedirect(error)) throw error;
      console.warn("[auth] Session locale indisponible, retour à la connexion", error);
      throw redirect({ to: "/auth" });
    }
  },
  component: () => (
    <AppShell>
      <ActifGate>
        <MfaGate>
          <RouteGuard>
            <Outlet />
          </RouteGuard>
        </MfaGate>
      </ActifGate>
    </AppShell>
  ),
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
