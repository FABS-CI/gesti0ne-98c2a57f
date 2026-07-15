import { useState } from "react";
import React from "react";
import { Copy, Plus, Search, Trash2, Users } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  useRolesQuery,
  useDeleteRole,
  useDuplicateRole,
  useToggleRoleActive,
  useUserRoleAssignsQuery,
} from "@/hooks/use-roles-permissions";
import { RoleFormDialog } from "./RoleFormDialog";
import type { RbacRole } from "@/lib/rbac-api";
import { useConfirmDelete } from "@/hooks/use-confirm-delete";

// ── Mémo row ──────────────────────────────────────────────────────────────
interface RoleRowProps {
  role: RbacRole;
  parent: RbacRole | undefined;
  userCount: number;
  onEdit: (r: RbacRole) => void;
  onDelete: (r: RbacRole) => void;
  onDuplicate: (r: RbacRole) => void;
  onToggleActive: (r: RbacRole, actif: boolean) => void;
}

const RoleRow = React.memo(function RoleRow({
  role: r,
  parent,
  userCount,
  onEdit,
  onDelete,
  onDuplicate,
  onToggleActive,
}: RoleRowProps) {
  return (
    <TableRow>
      <TableCell className="font-medium">{r.libelle}</TableCell>
      <TableCell className="font-mono text-xs">{r.code}</TableCell>
      <TableCell className="text-xs text-muted-foreground">{parent?.libelle ?? "—"}</TableCell>
      <TableCell>
        <Badge variant="outline" className="gap-1">
          <Users className="h-3 w-3" />
          {userCount}
        </Badge>
      </TableCell>
      <TableCell>
        <div className="flex items-center gap-2">
          <Switch
            checked={r.actif}
            disabled={r.systeme}
            onCheckedChange={(v) => onToggleActive(r, v)}
            aria-label={r.actif ? "Désactiver le rôle" : "Activer le rôle"}
          />
          {r.systeme && (
            <Badge variant="secondary" className="text-[10px]">
              Système
            </Badge>
          )}
        </div>
      </TableCell>
      <TableCell className="text-right whitespace-nowrap">
        <Button variant="ghost" size="sm" onClick={() => onEdit(r)}>
          Éditer
        </Button>
        <Button
          variant="ghost"
          size="sm"
          onClick={() => onDuplicate(r)}
          title="Dupliquer ce rôle avec ses permissions"
        >
          <Copy className="h-4 w-4" />
        </Button>
        {!r.systeme && (
          <Button variant="ghost" size="sm" onClick={() => onDelete(r)}>
            <Trash2 className="h-4 w-4 text-destructive" />
          </Button>
        )}
      </TableCell>
    </TableRow>
  );
});

// ── Onglet ────────────────────────────────────────────────────────────────
export function RolesTab() {
  const rolesQ = useRolesQuery();
  const assignsQ = useUserRoleAssignsQuery();
  const del = useDeleteRole();
  const dup = useDuplicateRole();
  const toggleActive = useToggleRoleActive();
  const { confirm, dialog: confirmDialog } = useConfirmDelete();
  const [editing, setEditing] = useState<RbacRole | null>(null);
  const [creating, setCreating] = useState(false);
  const [search, setSearch] = useState("");
  const [statut, setStatut] = useState<"tous" | "actif" | "inactif">("tous");

  const userCounts = React.useMemo(() => {
    const map = new Map<string, number>();
    for (const a of assignsQ.data ?? []) {
      map.set(a.role_id, (map.get(a.role_id) ?? 0) + 1);
    }
    return map;
  }, [assignsQ.data]);

  const filtered = (rolesQ.data ?? []).filter((r) => {
    const q = search.trim().toLowerCase();
    if (q && !`${r.libelle} ${r.code} ${r.description ?? ""}`.toLowerCase().includes(q))
      return false;
    if (statut === "actif" && !r.actif) return false;
    if (statut === "inactif" && r.actif) return false;
    return true;
  });

  async function handleDelete(r: RbacRole) {
    const res = await confirm({
      title: "Supprimer ce rôle ?",
      entityLabel: "le rôle",
      entityName: r.libelle,
      description:
        "Les utilisateurs rattachés perdront ce rôle. Les rôles système ne sont pas supprimables.",
    });
    if (res === false) return;
    del.mutate(r.role_id);
  }

  function handleDuplicate(r: RbacRole) {
    const proposedLibelle = `${r.libelle} (copie)`;
    const libelle = window.prompt("Libellé du nouveau rôle", proposedLibelle);
    if (!libelle) return;
    const proposedCode = `${r.code}_copy`;
    const code = window.prompt("Code (identifiant unique)", proposedCode);
    if (!code) return;
    dup.mutate({
      sourceRoleId: r.role_id,
      newCode: code.trim().toLowerCase().replace(/\s+/g, "_"),
      newLibelle: libelle.trim(),
    });
  }

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle>Rôles ({rolesQ.data?.length ?? 0})</CardTitle>
        <div className="flex flex-wrap items-center gap-2">
          <div className="relative">
            <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Rechercher un rôle…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-56 pl-8"
            />
          </div>
          <Select value={statut} onValueChange={(v) => setStatut(v as typeof statut)}>
            <SelectTrigger className="w-36">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="tous">Tous</SelectItem>
              <SelectItem value="actif">Actifs</SelectItem>
              <SelectItem value="inactif">Inactifs</SelectItem>
            </SelectContent>
          </Select>
          <Button onClick={() => setCreating(true)} size="sm">
            <Plus className="mr-2 h-4 w-4" />
            Nouveau rôle
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Libellé</TableHead>
              <TableHead>Code</TableHead>
              <TableHead>Hérite de</TableHead>
              <TableHead>Utilisateurs</TableHead>
              <TableHead>Statut</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((r) => {
              const parent = rolesQ.data?.find((x) => x.role_id === r.hierite_de);
              return (
                <RoleRow
                  key={r.role_id}
                  role={r}
                  parent={parent}
                  userCount={userCounts.get(r.role_id) ?? 0}
                  onEdit={setEditing}
                  onDelete={handleDelete}
                  onDuplicate={handleDuplicate}
                  onToggleActive={(role, actif) =>
                    toggleActive.mutate({ roleId: role.role_id, actif })
                  }
                />
              );
            })}
          </TableBody>
        </Table>
      </CardContent>

      <RoleFormDialog open={creating} onOpenChange={setCreating} roles={rolesQ.data ?? []} />
      <RoleFormDialog
        open={!!editing}
        onOpenChange={(o) => !o && setEditing(null)}
        role={editing}
        roles={rolesQ.data ?? []}
      />
      {confirmDialog}
    </Card>
  );
}
