import { useMemo, useState } from "react";
import { Plus, Search, ShieldPlus, Users, Lock } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { cn } from "@/lib/utils";
import {
  useRolesQuery,
  useUserRoleAssignsQuery,
} from "@/hooks/use-roles-permissions";
import { MatrixTab } from "./MatrixTab";
import { RoleFormDialog } from "./RoleFormDialog";

/**
 * Vue "Console" : liste des rôles à gauche (sélectionnable),
 * matrice des permissions du rôle sélectionné à droite.
 */
export function RolesConsole() {
  const rolesQ = useRolesQuery();
  const assignsQ = useUserRoleAssignsQuery();
  const [selected, setSelected] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [creating, setCreating] = useState(false);

  const active = useMemo(
    () => (rolesQ.data ?? []).filter((r) => r.actif),
    [rolesQ.data],
  );
  const currentId = selected ?? active[0]?.role_id ?? null;

  const userCounts = useMemo(() => {
    const m = new Map<string, number>();
    for (const a of assignsQ.data ?? []) {
      m.set(a.role_id, (m.get(a.role_id) ?? 0) + 1);
    }
    return m;
  }, [assignsQ.data]);

  const q = search.trim().toLowerCase();
  const filtered = active.filter(
    (r) =>
      !q || `${r.libelle} ${r.code}`.toLowerCase().includes(q),
  );

  return (
    <div className="grid gap-4 lg:grid-cols-[320px_minmax(0,1fr)]">
      {/* -------- Colonne rôles -------- */}
      <Card className="lg:sticky lg:top-4 lg:h-[calc(100vh-8rem)]">
        <CardHeader className="space-y-3">
          <div className="flex items-center justify-between gap-2">
            <CardTitle className="text-base flex items-center gap-2">
              <ShieldPlus className="h-4 w-4 text-primary" />
              Rôles ({active.length})
            </CardTitle>
            <Button size="sm" onClick={() => setCreating(true)}>
              <Plus className="mr-1 h-4 w-4" />
              Nouveau
            </Button>
          </div>
          <div className="relative">
            <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Rechercher…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-8"
            />
          </div>
        </CardHeader>
        <CardContent className="p-2">
          <ScrollArea className="h-[calc(100vh-18rem)] pr-2">
            <ul className="space-y-1">
              {filtered.map((r) => {
                const isActive = r.role_id === currentId;
                const count = userCounts.get(r.role_id) ?? 0;
                return (
                  <li key={r.role_id}>
                    <button
                      type="button"
                      onClick={() => setSelected(r.role_id)}
                      className={cn(
                        "w-full rounded-md border px-3 py-2 text-left transition-colors",
                        "hover:bg-accent hover:text-accent-foreground",
                        isActive
                          ? "border-primary bg-primary/10 text-foreground shadow-sm"
                          : "border-transparent",
                      )}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-1.5 truncate font-medium text-sm">
                            {r.systeme && (
                              <Lock className="h-3 w-3 shrink-0 text-muted-foreground" />
                            )}
                            <span className="truncate">{r.libelle}</span>
                          </div>
                          <div className="font-mono text-[10px] text-muted-foreground truncate">
                            {r.code}
                          </div>
                        </div>
                        <Badge
                          variant="outline"
                          className="shrink-0 gap-1 text-[10px]"
                        >
                          <Users className="h-3 w-3" />
                          {count}
                        </Badge>
                      </div>
                    </button>
                  </li>
                );
              })}
              {filtered.length === 0 && (
                <li className="p-4 text-center text-xs text-muted-foreground">
                  Aucun rôle actif ne correspond.
                </li>
              )}
            </ul>
          </ScrollArea>
        </CardContent>
      </Card>

      {/* -------- Matrice -------- */}
      <div className="min-w-0">
        {currentId ? (
          <MatrixTab
            roleId={currentId}
            onRoleChange={setSelected}
            hideRoleSelect
          />
        ) : (
          <Card>
            <CardContent className="py-12 text-center text-sm text-muted-foreground">
              Sélectionnez un rôle pour ajuster ses permissions.
            </CardContent>
          </Card>
        )}
      </div>

      <RoleFormDialog
        open={creating}
        onOpenChange={setCreating}
        roles={rolesQ.data ?? []}
      />
    </div>
  );
}