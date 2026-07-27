import { createFileRoute } from "@tanstack/react-router";
import { Loader2, ShieldCheck } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { usePermissions } from "@/hooks/use-permissions";
import RolesAdmin from "@/components/security/RolesAdmin";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/roles-permissions")({
  component: RolesPermissionsPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function RolesPermissionsPage() {
  const { isSuperAdmin, isLoading } = usePermissions();

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }
  if (!isSuperAdmin) {
    return (
      <div className="p-8">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-destructive">
              <ShieldCheck className="h-5 w-5" /> Accès refusé
            </CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground">
            La gestion des rôles et permissions est réservée au Super Administrateur.
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="p-4 md:p-6">
      <RolesAdmin />
    </div>
  );
}
