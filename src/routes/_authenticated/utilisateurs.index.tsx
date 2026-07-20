import { createFileRoute } from "@tanstack/react-router";
import { UsersTab } from "@/components/roles-permissions/UsersTab";

import { authRouteHead } from "@/lib/route-head";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";
export const Route = createFileRoute("/_authenticated/utilisateurs/")({
  head: () => authRouteHead("Utilisateurs"),
  component: UtilisateursPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function UtilisateursPage() {
  return (
    <div className="container mx-auto p-4 md:p-6 space-y-4">
      <div>
        <h1 className="text-2xl font-bold">Utilisateurs</h1>
        <p className="text-sm text-muted-foreground">
          Gestion des comptes, rôles et statuts d'activation
        </p>
      </div>
      <UsersTab />
    </div>
  );
}