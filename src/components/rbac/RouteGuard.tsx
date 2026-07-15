import { useEffect, type ReactNode } from "react";
import { useNavigate, useRouterState } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";

import { usePermissions } from "@/hooks/use-permissions";
import { getRoutePermission, isSuperAdminOnlyRoute } from "@/lib/route-permissions";
import { logPermissionDenied } from "@/lib/rbac-api";

/**
 * Garde de route RBAC v2. Vérifie que l'utilisateur possède la permission
 * `.voir` associée à la route courante. Redirige vers `/dashboard` (ou
 * `/profil` en dernier recours) avec un toast si l'accès est refusé.
 *
 * Comportement conservateur : une route non mappée passe (fallback autorisé)
 * pour ne rien casser pendant la migration progressive.
 */
export function RouteGuard({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { has, hasAny, isLoading, isSuperAdmin } = usePermissions();
  const navigate = useNavigate();

  const required = getRoutePermission(pathname);
  const adminOnly = isSuperAdminOnlyRoute(pathname);
  // Fallback strict (batch P1) : une route non mappée est refusée.
  // - `null`  : route explicitement publique (profil, notifications…)
  // - string  : permission requise
  // - undefined : refusé sauf super_admin
  const allowed =
    isSuperAdmin ||
    (!adminOnly &&
      (required === null ||
        (typeof required === "string" && has(required)) ||
        (Array.isArray(required) && hasAny(required))));

  useEffect(() => {
    if (isLoading || allowed) return;
    // Ne pas re-loguer / rediriger si on est déjà sur la page 403.
    if (pathname === "/acces-refuse") return;
    const permLabel = Array.isArray(required) ? required.join("|") : (required ?? "");
    if (required) {
      void logPermissionDenied(permLabel, { path: pathname });
    }
    navigate({
      to: "/acces-refuse",
      search: { perm: permLabel, from: pathname },
      replace: true,
    });
  }, [isLoading, allowed, required, navigate, pathname]);

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
      </div>
    );
  }
  if (!allowed) return null;
  return <>{children}</>;
}
