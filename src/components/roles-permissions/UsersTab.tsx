import React, { useMemo, useState } from "react";
import {
  Search,
  UserPlus,
  Pencil,
  PowerOff,
  Power,
  Loader2,
  Trash2,
  ShieldCheck,
  ShieldOff,
  RotateCcw,
  ShieldPlus,
  ShieldX,
} from "lucide-react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { Link } from "@tanstack/react-router";
import { toast } from "sonner";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Checkbox } from "@/components/ui/checkbox";
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
import { ResponsiveTable } from "@/components/layout/ResponsiveTable";
import {
  useRolesQuery,
  useUserProfilesQuery,
  useUserRoleAssignsQuery,
} from "@/hooks/use-roles-permissions";
import { adminDeactivateUser, adminReactivateUser, adminDeleteUser } from "@/lib/users-admin.functions";
import { mfaAdminSetRequired, mfaAdminResetUser } from "@/lib/mfa.functions";
import { Switch } from "@/components/ui/switch";
import type { UserProfile } from "@/lib/rbac-api";

export function UsersTab() {
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<"all" | "actif" | "inactif">("all");
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const qc = useQueryClient();
  const usersQ = useUserProfilesQuery();
  const rolesQ = useRolesQuery();
  const assignsQ = useUserRoleAssignsQuery();
  const deactivateFn = useServerFn(adminDeactivateUser);
  const reactivateFn = useServerFn(adminReactivateUser);
  const deleteFn = useServerFn(adminDeleteUser);
  const mfaSetRequiredFn = useServerFn(mfaAdminSetRequired);
  const mfaResetFn = useServerFn(mfaAdminResetUser);

  const deactivate = useMutation({
    mutationFn: (userId: string) => deactivateFn({ data: { user_id: userId } }),
    onSuccess: () => {
      toast.success("Utilisateur désactivé");
      qc.invalidateQueries({ queryKey: ["rbac", "user-profiles"] });
      qc.invalidateQueries({ queryKey: ["rbac", "user-role-assigns"] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const reactivate = useMutation({
    mutationFn: (userId: string) => reactivateFn({ data: { user_id: userId, role_ids: [] } }),
    onSuccess: () => {
      toast.success("Utilisateur réactivé");
      qc.invalidateQueries({ queryKey: ["rbac", "user-profiles"] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const remove = useMutation({
    mutationFn: (userId: string) => deleteFn({ data: { user_id: userId } }),
    onSuccess: () => {
      toast.success("Utilisateur supprimé");
      qc.invalidateQueries({ queryKey: ["rbac", "user-profiles"] });
      qc.invalidateQueries({ queryKey: ["rbac", "user-role-assigns"] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const mfaToggle = useMutation({
    mutationFn: (v: { userId: string; required: boolean }) =>
      mfaSetRequiredFn({ data: { targetUserId: v.userId, required: v.required } }),
    onMutate: async (v) => {
      await qc.cancelQueries({ queryKey: ["rbac", "user-profiles"] });
      const prev = qc.getQueryData<UserProfile[]>(["rbac", "user-profiles"]);
      qc.setQueryData<UserProfile[]>(["rbac", "user-profiles"], (old) =>
        (old ?? []).map((u) => (u.id === v.userId ? { ...u, mfa_required: v.required } : u)),
      );
      return { prev };
    },
    onError: (e: Error, _v, ctx) => {
      if (ctx?.prev) qc.setQueryData(["rbac", "user-profiles"], ctx.prev);
      toast.error(e.message);
    },
    onSuccess: (_r, v) => {
      toast.success(v.required ? "MFA activé" : "MFA désactivé");
    },
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ["rbac", "user-profiles"] });
    },
  });

  const mfaReset = useMutation({
    mutationFn: (userId: string) => mfaResetFn({ data: { targetUserId: userId } }),
    onSuccess: () => {
      toast.success("MFA réinitialisé — l'utilisateur devra se ré-enrôler");
      qc.invalidateQueries({ queryKey: ["rbac", "user-profiles"] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const bulkMfa = useMutation({
    mutationFn: async (v: { userIds: string[]; required: boolean }) => {
      const res = { ok: 0, ko: 0, errors: [] as string[] };
      for (const id of v.userIds) {
        try {
          await mfaSetRequiredFn({ data: { targetUserId: id, required: v.required } });
          res.ok++;
        } catch (e) {
          res.ko++;
          res.errors.push((e as Error).message);
        }
      }
      return res;
    },
    onSuccess: (r, v) => {
      if (r.ko === 0)
        toast.success(
          `MFA ${v.required ? "activé" : "désactivé"} pour ${r.ok} utilisateur(s)`,
        );
      else toast.warning(`${r.ok} ok, ${r.ko} échec(s) : ${r.errors[0]}`);
      qc.invalidateQueries({ queryKey: ["rbac", "user-profiles"] });
      setSelected(new Set());
    },
  });

  const bulkDelete = useMutation({
    mutationFn: async (userIds: string[]) => {
      const results = { ok: 0, ko: 0, errors: [] as string[] };
      for (const id of userIds) {
        try {
          await deleteFn({ data: { user_id: id } });
          results.ok++;
        } catch (e) {
          results.ko++;
          results.errors.push((e as Error).message);
        }
      }
      return results;
    },
    onSuccess: (r) => {
      if (r.ko === 0) toast.success(`${r.ok} utilisateur(s) supprimé(s)`);
      else toast.warning(`${r.ok} supprimé(s), ${r.ko} échec(s) : ${r.errors[0]}`);
      qc.invalidateQueries({ queryKey: ["rbac", "user-profiles"] });
      qc.invalidateQueries({ queryKey: ["rbac", "user-role-assigns"] });
    },
  });

  const filter = search.trim().toLowerCase();
  const activeRoles = (rolesQ.data ?? []).filter((r) => r.actif);
  const rolesByUser = useMemo(() => {
    const map = new Map<string, string[]>();
    for (const a of assignsQ.data ?? []) {
      const list = map.get(a.user_id) ?? [];
      list.push(a.role_id);
      map.set(a.user_id, list);
    }
    return map;
  }, [assignsQ.data]);
  const rolesById = useMemo(
    () => new Map(activeRoles.map((r) => [r.role_id, r])),
    [activeRoles],
  );

  const users = (usersQ.data ?? []).filter((u) => {
    if (
      filter &&
      !u.email?.toLowerCase().includes(filter) &&
      !u.nom_complet?.toLowerCase().includes(filter)
    ) {
      return false;
    }
    if (roleFilter !== "all") {
      const has = (rolesByUser.get(u.id) ?? []).includes(roleFilter);
      if (!has) return false;
    }
    if (statusFilter === "actif" && !u.actif) return false;
    if (statusFilter === "inactif" && u.actif) return false;
    return true;
  });

  const allVisibleSelected =
    users.length > 0 && users.every((u) => selected.has(u.id));
  const someVisibleSelected =
    users.some((u) => selected.has(u.id)) && !allVisibleSelected;
  function toggleAll(v: boolean) {
    const next = new Set(selected);
    if (v) users.forEach((u) => next.add(u.id));
    else users.forEach((u) => next.delete(u.id));
    setSelected(next);
  }
  function toggleOne(id: string, v: boolean) {
    const next = new Set(selected);
    if (v) next.add(id);
    else next.delete(id);
    setSelected(next);
  }
  const fmtDate = (iso?: string | null) =>
    iso
      ? new Date(iso).toLocaleDateString("fr-FR", {
          day: "2-digit",
          month: "short",
          year: "numeric",
        })
      : null;

  return (
    <>
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle>Utilisateurs ({users.length})</CardTitle>
        <div className="flex flex-wrap items-center gap-2">
          {selected.size > 0 && (
            <>
              <Badge variant="secondary" className="mr-1">
                {selected.size} sélectionné(s)
              </Badge>
              <Button
                variant="outline"
                size="sm"
                disabled={bulkMfa.isPending}
                onClick={() =>
                  bulkMfa.mutate({ userIds: [...selected], required: true })
                }
              >
                {bulkMfa.isPending && bulkMfa.variables?.required ? (
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                ) : (
                  <ShieldPlus className="mr-2 h-4 w-4" />
                )}
                Activer MFA
              </Button>
              <Button
                variant="outline"
                size="sm"
                disabled={bulkMfa.isPending}
                onClick={() =>
                  bulkMfa.mutate({ userIds: [...selected], required: false })
                }
              >
                {bulkMfa.isPending && !bulkMfa.variables?.required ? (
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                ) : (
                  <ShieldX className="mr-2 h-4 w-4" />
                )}
                Désactiver MFA
              </Button>
            </>
          )}
          <Select value={statusFilter} onValueChange={(v) => setStatusFilter(v as typeof statusFilter)}>
            <SelectTrigger className="w-36">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Tous</SelectItem>
              <SelectItem value="actif">Actifs</SelectItem>
              <SelectItem value="inactif">Inactifs</SelectItem>
            </SelectContent>
          </Select>
          <Select value={roleFilter} onValueChange={setRoleFilter}>
            <SelectTrigger className="w-48">
              <SelectValue placeholder="Filtrer par rôle" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Tous les rôles</SelectItem>
              {activeRoles.map((r) => (
                <SelectItem key={r.role_id} value={r.role_id}>
                  {r.libelle}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <div className="relative">
            <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Rechercher…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-64 pl-8"
            />
          </div>
          <Button asChild>
            <Link to="/utilisateurs/nouveau">
              <UserPlus className="mr-2 h-4 w-4" />
              Nouvel utilisateur
            </Link>
          </Button>
          <Button
            variant="destructive"
            disabled={bulkDelete.isPending}
            onClick={() => {
              // Cible tous les non-super_admin visibles dans le filtre courant
              const superRoleId = activeRoles.find((r) => r.code === "super_admin")?.role_id;
              const targets = users.filter((u) => {
                const rids = rolesByUser.get(u.id) ?? [];
                return !superRoleId || !rids.includes(superRoleId);
              });
              if (targets.length === 0) {
                toast.info("Aucun utilisateur à supprimer");
                return;
              }
              if (
                window.confirm(
                  `SUPPRIMER DÉFINITIVEMENT ${targets.length} utilisateur(s) ?\n\nLes super administrateurs sont préservés. Cette action est irréversible.`,
                )
              ) {
                bulkDelete.mutate(targets.map((u) => u.id));
              }
            }}
          >
            {bulkDelete.isPending ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <Trash2 className="mr-2 h-4 w-4" />
            )}
            Supprimer tous (sauf super admin)
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        <ResponsiveTable>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[36px]">
                  <Checkbox
                    checked={allVisibleSelected ? true : someVisibleSelected ? "indeterminate" : false}
                    onCheckedChange={(v) => toggleAll(!!v)}
                    aria-label="Tout sélectionner"
                  />
                </TableHead>
                <TableHead className="min-w-[220px]">Utilisateur</TableHead>
                <TableHead>Fonction / Département</TableHead>
                <TableHead>Rôles</TableHead>
                <TableHead>Statut</TableHead>
                <TableHead>MFA</TableHead>
                <TableHead className="w-[140px] text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {users.map((u) => {
                const uRoles = (rolesByUser.get(u.id) ?? [])
                  .map((rid) => rolesById.get(rid))
                  .filter(Boolean);
                return (
                  <TableRow key={u.id} className={u.actif ? "" : "opacity-60"}>
                    <TableCell>
                      <Checkbox
                        checked={selected.has(u.id)}
                        onCheckedChange={(v) => toggleOne(u.id, !!v)}
                        aria-label={`Sélectionner ${u.email}`}
                      />
                    </TableCell>
                    <TableCell>
                      <div className="font-medium">{u.nom_complet || "—"}</div>
                      <div className="text-xs text-muted-foreground">{u.email}</div>
                      {u.telephone && (
                        <div className="text-xs text-muted-foreground">{u.telephone}</div>
                      )}
                    </TableCell>
                    <TableCell className="text-sm">
                      <div>{u.fonction || "—"}</div>
                      <div className="text-xs text-muted-foreground">{u.departement || "—"}</div>
                    </TableCell>
                    <TableCell>
                      {uRoles.length === 0 ? (
                        <span className="text-xs text-muted-foreground">Aucun rôle</span>
                      ) : (
                        <div className="flex flex-wrap gap-1">
                          {uRoles.map((r) => (
                            <Badge key={r!.role_id} variant="secondary" className="text-xs">
                              {r!.libelle}
                            </Badge>
                          ))}
                        </div>
                      )}
                    </TableCell>
                    <TableCell>
                      {u.actif ? (
                        <Badge className="bg-emerald-100 text-emerald-800 hover:bg-emerald-100">
                          Actif
                        </Badge>
                      ) : (
                        <Badge variant="outline">Inactif</Badge>
                      )}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Switch
                          checked={!!u.mfa_required}
                          disabled={mfaToggle.isPending}
                          onCheckedChange={(v) =>
                            mfaToggle.mutate({ userId: u.id, required: v })
                          }
                          aria-label="Exiger MFA"
                        />
                        <div className="flex flex-col gap-0.5">
                          {u.mfa_enrolled_at ? (
                            <Badge className="bg-emerald-100 text-emerald-800 hover:bg-emerald-100 gap-1 w-fit">
                              <ShieldCheck className="h-3 w-3" /> Enrôlé
                            </Badge>
                          ) : u.mfa_required ? (
                            <Badge variant="outline" className="gap-1 w-fit border-amber-400 text-amber-700">
                              <ShieldOff className="h-3 w-3" /> En attente
                            </Badge>
                          ) : (
                            <Badge variant="outline" className="gap-1 w-fit text-muted-foreground">
                              <ShieldOff className="h-3 w-3" /> Désactivé
                            </Badge>
                          )}
                          {u.mfa_enrolled_at && (
                            <span className="text-[10px] text-muted-foreground">
                              depuis le {fmtDate(u.mfa_enrolled_at)}
                            </span>
                          )}
                        </div>
                        {u.mfa_enrolled_at && (
                          <Button aria-label="Réinitialiser le MFA"
                            variant="ghost"
                            size="icon"
                            disabled={mfaReset.isPending}
                            title="Réinitialiser le MFA"
                            onClick={() => {
                              if (
                                window.confirm(
                                  `Réinitialiser le MFA de ${u.email} ?\n\nSes secrets, codes de secours et sessions MFA seront supprimés. L'utilisateur devra se ré-enrôler à la prochaine connexion.`,
                                )
                              ) {
                                mfaReset.mutate(u.id);
                              }
                            }}
                          >
                            {mfaReset.isPending ? (
                              <Loader2 className="h-4 w-4 animate-spin" />
                            ) : (
                              <RotateCcw className="h-4 w-4" />
                            )}
                          </Button>
                        )}
                      </div>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-1">
                        <Button variant="ghost" size="icon" asChild>
                          <Link
                            to="/utilisateurs/$userId/modifier"
                            params={{ userId: u.id }}
                          >
                            <Pencil className="h-4 w-4" />
                          </Link>
                        </Button>
                        {u.actif ? (
                          <Button
                            variant="ghost"
                            size="icon"
                            disabled={deactivate.isPending}
                            onClick={() => {
                              if (
                                window.confirm(
                                  `Désactiver ${u.email} ?\n\nLe compte sera désactivé et tous ses rôles retirés. Les données métier restent intactes.`,
                                )
                              ) {
                                deactivate.mutate(u.id);
                              }
                            }}
                          >
                            {deactivate.isPending ? (
                              <Loader2 className="h-4 w-4 animate-spin" />
                            ) : (
                              <PowerOff className="h-4 w-4 text-destructive" />
                            )}
                          </Button>
                        ) : (
                          <Button
                            variant="ghost"
                            size="icon"
                            disabled={reactivate.isPending}
                            onClick={() => reactivate.mutate(u.id)}
                          >
                            {reactivate.isPending ? (
                              <Loader2 className="h-4 w-4 animate-spin" />
                            ) : (
                              <Power className="h-4 w-4 text-emerald-600" />
                            )}
                          </Button>
                        )}
                        <Button
                          variant="ghost"
                          size="icon"
                          disabled={remove.isPending}
                          onClick={() => {
                            if (
                              window.confirm(
                                `SUPPRIMER DÉFINITIVEMENT ${u.email} ?\n\nLe compte auth et son profil seront supprimés. Les enregistrements métier créés par cet utilisateur seront conservés (auteur mis à NULL, nom conservé dans created_by_nom).\n\nCette action est irréversible.`,
                              )
                            ) {
                              remove.mutate(u.id);
                            }
                          }}
                        >
                          {remove.isPending ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <Trash2 className="h-4 w-4 text-destructive" />
                          )}
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </ResponsiveTable>
      </CardContent>
    </Card>
    </>
  );
}
