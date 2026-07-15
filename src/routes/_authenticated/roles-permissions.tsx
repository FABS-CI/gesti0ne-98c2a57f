import { createFileRoute } from "@tanstack/react-router";
import {
  Loader2,
  ShieldCheck,
  LayoutGrid,
  Users as UsersIcon,
  History,
  Settings2,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { usePermissions } from "@/hooks/use-permissions";
import { RolesTab } from "@/components/roles-permissions/RolesTab";
import { RolesConsole } from "@/components/roles-permissions/RolesConsole";
import { UsersTab } from "@/components/roles-permissions/UsersTab";
import { AuditTab } from "@/components/roles-permissions/AuditTab";
import { SyncRbacButton } from "@/components/roles-permissions/SyncRbacButton";

export const Route = createFileRoute("/_authenticated/roles-permissions")({
  component: RolesPermissionsPage,
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
    <div className="space-y-6 p-4 md:p-6">
      <header className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4 rounded-lg border bg-gradient-to-br from-primary/5 via-background to-background p-4 md:flex md:items-center">
        <div className="flex min-w-0 items-center gap-3">
          <div className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary">
            <ShieldCheck className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <h1 className="truncate text-xl font-bold sm:text-2xl">
              Rôles &amp; Permissions
            </h1>
            <p className="text-xs text-muted-foreground sm:text-sm">
              Console RBAC — attribution dynamique des droits, sans redéploiement.
            </p>
          </div>
        </div>
        <SyncRbacButton />
      </header>

      <Tabs defaultValue="console" className="w-full">
        <TabsList className="grid w-full grid-cols-2 md:inline-grid md:w-auto md:grid-cols-4">
          <TabsTrigger value="console">
            <LayoutGrid className="mr-2 h-4 w-4" />
            Console
          </TabsTrigger>
          <TabsTrigger value="roles">
            <Settings2 className="mr-2 h-4 w-4" />
            Gérer les rôles
          </TabsTrigger>
          <TabsTrigger value="users">
            <UsersIcon className="mr-2 h-4 w-4" />
            Utilisateurs
          </TabsTrigger>
          <TabsTrigger value="audit">
            <History className="mr-2 h-4 w-4" />
            Historique
          </TabsTrigger>
        </TabsList>

        <TabsContent value="console" className="mt-4">
          <RolesConsole />
        </TabsContent>
        <TabsContent value="roles" className="mt-4">
          <RolesTab />
        </TabsContent>
        <TabsContent value="users" className="mt-4">
          <UsersTab />
        </TabsContent>
        <TabsContent value="audit" className="mt-4">
          <AuditTab />
        </TabsContent>
      </Tabs>
    </div>
  );
}
