import { createFileRoute } from "@tanstack/react-router";
import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { friendlyError } from "@/lib/friendly-error";
import { RouteError } from "@/components/route-boundaries";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Progress } from "@/components/ui/progress";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import {
  ChevronDown, ChevronRight, Plus, Search, Shield, Users, Trash2, UserPlus, X,
  CheckCircle2, XCircle, GitBranch, History as HistoryIcon, Stethoscope, Download, AlertTriangle,
} from "lucide-react";

export const Route = createFileRoute("/_authenticated/admin/roles-v2")({
  component: RolesV2Page,
  errorComponent: RouteError,
});

// ---- types ----
type Domain = { code: string; label: string; icon: string | null; sort: number };
type Module = { code: string; domain_code: string; label: string; icon: string | null; sort: number };
type Resource = { code: string; module_code: string; label: string; kind: string; sort: number };
type Permission = { code: string; resource_code: string; action: string; label: string };
type Role = { code: string; label: string; description: string | null; is_system: boolean; sort: number };
type RolePerm = { role_code: string; perm_code: string; granted: boolean };
type RoleParent = { role_code: string; parent_code: string };
type UserRole = { user_id: string; role_code: string };
type Profile = { id: string; email: string | null; nom: string | null; prenoms: string | null };
type PermDep = { perm_code: string; requires_code: string };
type AuditRow = {
  id: number; actor_id: string | null; action: string; target_type: string;
  target_id: string; before: unknown; after: unknown; at: string;
};

// ---- action colors ----
const ACTION_COLORS: Record<string, string> = {
  voir: "bg-blue-500/10 text-blue-700 dark:text-blue-300",
  creer: "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300",
  modifier: "bg-amber-500/10 text-amber-700 dark:text-amber-300",
  supprimer: "bg-red-500/10 text-red-700 dark:text-red-300",
  valider: "bg-violet-500/10 text-violet-700 dark:text-violet-300",
  annuler: "bg-orange-500/10 text-orange-700 dark:text-orange-300",
  approuver: "bg-teal-500/10 text-teal-700 dark:text-teal-300",
  cloturer: "bg-slate-500/10 text-slate-700 dark:text-slate-300",
  exporter: "bg-cyan-500/10 text-cyan-700 dark:text-cyan-300",
  imprimer: "bg-indigo-500/10 text-indigo-700 dark:text-indigo-300",
  admin: "bg-fuchsia-500/10 text-fuchsia-700 dark:text-fuchsia-300",
};
const actionColor = (a: string) =>
  ACTION_COLORS[a] ?? "bg-muted text-muted-foreground";

// ---- page ----
function RolesV2Page() {
  const [loading, setLoading] = useState(true);
  const [domains, setDomains] = useState<Domain[]>([]);
  const [modules, setModules] = useState<Module[]>([]);
  const [resources, setResources] = useState<Resource[]>([]);
  const [perms, setPerms] = useState<Permission[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [rolePerms, setRolePerms] = useState<RolePerm[]>([]);
  const [roleParents, setRoleParents] = useState<RoleParent[]>([]);
  const [userRoles, setUserRoles] = useState<UserRole[]>([]);
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [deps, setDeps] = useState<PermDep[]>([]);
  const [selectedRole, setSelectedRole] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [actionFilter, setActionFilter] = useState<string | null>(null);
  const [expandedDomains, setExpandedDomains] = useState<Set<string>>(new Set());
  const [expandedModules, setExpandedModules] = useState<Set<string>>(new Set());
  const [diagOpen, setDiagOpen] = useState(false);

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const [d, m, r, p, ro, rp, par, ur, pr, dp] = await Promise.all([
        supabase.from("rbac2_domains").select("*").order("sort"),
        supabase.from("rbac2_modules").select("*").order("sort"),
        supabase.from("rbac2_resources").select("*").order("sort"),
        supabase.from("rbac2_permissions").select("*").order("code"),
        supabase.from("rbac2_roles").select("*").order("sort"),
        supabase.from("rbac2_role_perms").select("*"),
        supabase.from("rbac2_role_parents").select("*"),
        supabase.from("rbac2_user_roles").select("*"),
        supabase.from("profiles").select("id, email, nom, prenoms"),
        supabase.from("rbac2_perm_deps").select("*"),
      ]);
      const anyErr = [d, m, r, p, ro, rp, par, ur, pr, dp].find((x) => x.error);
      if (anyErr?.error) throw anyErr.error;
      setDomains((d.data ?? []) as Domain[]);
      setModules((m.data ?? []) as Module[]);
      setResources((r.data ?? []) as Resource[]);
      setPerms((p.data ?? []) as Permission[]);
      setRoles((ro.data ?? []) as Role[]);
      setRolePerms((rp.data ?? []) as RolePerm[]);
      setRoleParents((par.data ?? []) as RoleParent[]);
      setUserRoles((ur.data ?? []) as UserRole[]);
      setProfiles((pr.data ?? []) as Profile[]);
      setDeps((dp.data ?? []) as PermDep[]);
      if (!selectedRole && (ro.data ?? []).length > 0) {
        setSelectedRole((ro.data as Role[])[0].code);
      }
    } catch (e) {
      toast.error(friendlyError(e));
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => { reload(); }, [reload]);

  // ---- derived data ----
  const permByCode = useMemo(() => {
    const m = new Map<string, Permission>();
    perms.forEach((p) => m.set(p.code, p));
    return m;
  }, [perms]);

  const roleByCode = useMemo(() => {
    const m = new Map<string, Role>();
    roles.forEach((r) => m.set(r.code, r));
    return m;
  }, [roles]);

  const usersByRole = useMemo(() => {
    const m = new Map<string, string[]>();
    userRoles.forEach((ur) => {
      const arr = m.get(ur.role_code) ?? [];
      arr.push(ur.user_id);
      m.set(ur.role_code, arr);
    });
    return m;
  }, [userRoles]);

  const parentsByRole = useMemo(() => {
    const m = new Map<string, string[]>();
    roleParents.forEach((rp) => {
      const arr = m.get(rp.role_code) ?? [];
      arr.push(rp.parent_code);
      m.set(rp.role_code, arr);
    });
    return m;
  }, [roleParents]);

  // Fermeture transitive côté client pour affichage
  const closureOf = useCallback((roleCode: string): Set<string> => {
    const seen = new Set<string>([roleCode]);
    const stack = [roleCode];
    while (stack.length) {
      const cur = stack.pop()!;
      const ps = parentsByRole.get(cur) ?? [];
      for (const p of ps) if (!seen.has(p)) { seen.add(p); stack.push(p); }
    }
    return seen;
  }, [parentsByRole]);

  const permStateFor = useCallback((roleCode: string) => {
    // returns Map<permCode, {direct?: boolean granted, inherited?: boolean granted, deniedInChain: boolean}>
    const chain = closureOf(roleCode);
    const map = new Map<string, { direct?: boolean; inheritedGrant?: boolean; deniedInChain: boolean }>();
    for (const rp of rolePerms) {
      if (!chain.has(rp.role_code)) continue;
      const cur = map.get(rp.perm_code) ?? { deniedInChain: false };
      if (rp.role_code === roleCode) cur.direct = rp.granted;
      else if (rp.granted) cur.inheritedGrant = true;
      if (!rp.granted) cur.deniedInChain = true;
      map.set(rp.perm_code, cur);
    }
    return map;
  }, [rolePerms, closureOf]);

  const filteredPerms = useMemo(() => {
    const s = search.trim().toLowerCase();
    return perms.filter((p) => {
      if (actionFilter && p.action !== actionFilter) return false;
      if (!s) return true;
      return p.code.toLowerCase().includes(s) || p.label.toLowerCase().includes(s);
    });
  }, [perms, search, actionFilter]);

  const availableActions = useMemo(() => {
    const s = new Set<string>();
    perms.forEach((p) => s.add(p.action));
    return Array.from(s).sort();
  }, [perms]);

  // ---- actions ----
  const toggleDomain = (code: string) => {
    const s = new Set(expandedDomains);
    s.has(code) ? s.delete(code) : s.add(code);
    setExpandedDomains(s);
  };
  const toggleModule = (code: string) => {
    const s = new Set(expandedModules);
    s.has(code) ? s.delete(code) : s.add(code);
    setExpandedModules(s);
  };

  // Fermeture transitive côté client des dépendances de permissions.
  const depClosure = useCallback((permCode: string): Set<string> => {
    const seen = new Set<string>();
    const stack = [permCode];
    while (stack.length) {
      const cur = stack.pop()!;
      for (const d of deps) {
        if (d.perm_code === cur && !seen.has(d.requires_code)) {
          seen.add(d.requires_code);
          stack.push(d.requires_code);
        }
      }
    }
    return seen;
  }, [deps]);

  const savePerm = async (roleCode: string, permCode: string, next: "grant" | "deny" | "clear") => {
    try {
      if (next === "clear") {
        const { error } = await supabase.from("rbac2_role_perms")
          .delete().eq("role_code", roleCode).eq("perm_code", permCode);
        if (error) throw error;
      } else {
        const rows: RolePerm[] = [{ role_code: roleCode, perm_code: permCode, granted: next === "grant" }];
        // Auto-application des dépendances requises quand on accorde
        if (next === "grant") {
          for (const req of depClosure(permCode)) {
            const already = rolePerms.some(
              (x) => x.role_code === roleCode && x.perm_code === req && x.granted,
            );
            if (!already) rows.push({ role_code: roleCode, perm_code: req, granted: true });
          }
        }
        const { error } = await supabase.from("rbac2_role_perms").upsert(rows);
        if (error) throw error;
        if (rows.length > 1) {
          toast.success(`Dépendances ajoutées : +${rows.length - 1}`);
        }
      }
      // maj optimiste
      setRolePerms((prev) => {
        if (next === "clear") {
          return prev.filter((x) => !(x.role_code === roleCode && x.perm_code === permCode));
        }
        const codesTouched = new Set<string>([permCode, ...(next === "grant" ? Array.from(depClosure(permCode)) : [])]);
        const others = prev.filter((x) => !(x.role_code === roleCode && codesTouched.has(x.perm_code)));
        const added: RolePerm[] = [{ role_code: roleCode, perm_code: permCode, granted: next === "grant" }];
        if (next === "grant") {
          for (const req of codesTouched) if (req !== permCode) added.push({ role_code: roleCode, perm_code: req, granted: true });
        }
        return [...others, ...added];
      });
    } catch (e) {
      toast.error(friendlyError(e));
    }
  };

  const bulkSetModule = async (roleCode: string, moduleCode: string, grantAll: boolean) => {
    const modResources = new Set(resources.filter((r) => r.module_code === moduleCode).map((r) => r.code));
    const modPerms = perms.filter((p) => modResources.has(p.resource_code));
    try {
      const rows = modPerms.map((p) => ({ role_code: roleCode, perm_code: p.code, granted: grantAll }));
      if (rows.length === 0) return;
      const { error } = await supabase.from("rbac2_role_perms").upsert(rows);
      if (error) throw error;
      setRolePerms((prev) => {
        const codes = new Set(modPerms.map((p) => p.code));
        const others = prev.filter((x) => !(x.role_code === roleCode && codes.has(x.perm_code)));
        return [...others, ...rows];
      });
      toast.success(`Module ${grantAll ? "activé" : "désactivé"}`);
    } catch (e) {
      toast.error(friendlyError(e));
    }
  };

  const toggleParent = async (roleCode: string, parentCode: string) => {
    const has = (parentsByRole.get(roleCode) ?? []).includes(parentCode);
    try {
      if (has) {
        const { error } = await supabase.from("rbac2_role_parents")
          .delete().eq("role_code", roleCode).eq("parent_code", parentCode);
        if (error) throw error;
        setRoleParents((prev) => prev.filter((x) => !(x.role_code === roleCode && x.parent_code === parentCode)));
      } else {
        const { error } = await supabase.from("rbac2_role_parents")
          .insert({ role_code: roleCode, parent_code: parentCode });
        if (error) throw error;
        setRoleParents((prev) => [...prev, { role_code: roleCode, parent_code: parentCode }]);
      }
    } catch (e) {
      toast.error(friendlyError(e));
    }
  };

  const assignUser = async (roleCode: string, userId: string) => {
    try {
      const { data: authData } = await supabase.auth.getUser();
      const { error } = await supabase.from("rbac2_user_roles")
        .insert({ user_id: userId, role_code: roleCode, granted_by: authData?.user?.id ?? null });
      if (error) throw error;
      setUserRoles((prev) => [...prev, { user_id: userId, role_code: roleCode }]);
      toast.success("Utilisateur assigné");
    } catch (e) {
      toast.error(friendlyError(e));
    }
  };

  const revokeUser = async (roleCode: string, userId: string) => {
    try {
      const { error } = await supabase.from("rbac2_user_roles")
        .delete().eq("role_code", roleCode).eq("user_id", userId);
      if (error) throw error;
      setUserRoles((prev) => prev.filter((x) => !(x.user_id === userId && x.role_code === roleCode)));
      toast.success("Rôle révoqué");
    } catch (e) {
      toast.error(friendlyError(e));
    }
  };

  const createRole = async (code: string, label: string, description: string) => {
    try {
      const { error } = await supabase.from("rbac2_roles")
        .insert({ code, label, description: description || null, is_system: false, sort: 500 });
      if (error) throw error;
      toast.success("Rôle créé");
      await reload();
      setSelectedRole(code);
    } catch (e) {
      toast.error(friendlyError(e));
    }
  };

  const deleteRole = async (code: string) => {
    if (!confirm(`Supprimer le rôle "${code}" ? Cette action retire aussi toutes ses attributions.`)) return;
    try {
      const { error } = await supabase.from("rbac2_roles").delete().eq("code", code);
      if (error) throw error;
      toast.success("Rôle supprimé");
      setSelectedRole(null);
      await reload();
    } catch (e) {
      toast.error(friendlyError(e));
    }
  };

  const selected = selectedRole ? roleByCode.get(selectedRole) : null;

  return (
    <div className="p-4 h-full flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <Shield className="h-6 w-6 text-primary" />
            Rôles & Permissions
            <Badge variant="secondary" className="ml-2">v2</Badge>
          </h1>
          <p className="text-sm text-muted-foreground">
            Console inspirée d'Odoo Enterprise · {roles.length} rôles · {perms.length} permissions · {domains.length} domaines
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={() => setDiagOpen(true)}>
            <Stethoscope className="h-4 w-4 mr-2" />Diagnostic
          </Button>
          <CreateRoleDialog onCreate={createRole} />
        </div>
      </div>

      {loading ? (
        <Card className="p-8 text-center text-muted-foreground">Chargement du catalogue…</Card>
      ) : (
        <div className="grid grid-cols-12 gap-4 flex-1 min-h-0">
          {/* Colonne rôles */}
          <Card className="col-span-3 flex flex-col min-h-0">
            <div className="p-3 border-b">
              <div className="text-sm font-semibold mb-2">Rôles</div>
              <Input placeholder="Filtrer…" className="h-8" onChange={(e) => {
                const s = e.target.value.toLowerCase();
                setRoles((prev) => [...prev].sort((a, b) => {
                  const am = a.label.toLowerCase().includes(s) ? 0 : 1;
                  const bm = b.label.toLowerCase().includes(s) ? 0 : 1;
                  return am - bm || a.sort - b.sort;
                }));
              }} />
            </div>
            <ScrollArea className="flex-1">
              <ul className="p-2 space-y-1">
                {roles.map((r) => {
                  const nUsers = (usersByRole.get(r.code) ?? []).length;
                  const nGrants = rolePerms.filter((x) => x.role_code === r.code && x.granted).length;
                  const isActive = selectedRole === r.code;
                  return (
                    <li key={r.code}>
                      <button
                        onClick={() => setSelectedRole(r.code)}
                        className={`w-full text-left px-2 py-2 rounded-md border transition ${
                          isActive ? "bg-primary/10 border-primary" : "hover:bg-muted border-transparent"
                        }`}
                      >
                        <div className="flex items-center justify-between gap-2">
                          <span className="text-sm font-medium truncate">{r.label}</span>
                          {r.is_system && <Badge variant="outline" className="text-[10px] shrink-0">sys</Badge>}
                        </div>
                        <div className="text-xs text-muted-foreground mt-0.5 flex items-center gap-3">
                          <span className="flex items-center gap-1"><Shield className="h-3 w-3" />{nGrants}</span>
                          <span className="flex items-center gap-1"><Users className="h-3 w-3" />{nUsers}</span>
                        </div>
                      </button>
                    </li>
                  );
                })}
              </ul>
            </ScrollArea>
          </Card>

          {/* Colonne arbre permissions */}
          <Card className="col-span-6 flex flex-col min-h-0">
            <div className="p-3 border-b space-y-2">
              <div className="flex items-center justify-between">
                <div className="text-sm font-semibold">
                  Permissions {selected ? <span className="text-muted-foreground">— {selected.label}</span> : ""}
                </div>
                {selected && (
                  <div className="text-xs text-muted-foreground">
                    Cliquez pour <span className="text-emerald-600">accorder</span>, re-cliquez pour <span className="text-red-600">refuser</span>, re-cliquez pour héritage
                  </div>
                )}
              </div>
              <div className="flex items-center gap-2">
                <div className="relative flex-1">
                  <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    className="pl-8 h-8"
                    placeholder="Rechercher une permission…"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>
                <select
                  className="h-8 rounded-md border bg-background px-2 text-sm"
                  value={actionFilter ?? ""}
                  onChange={(e) => setActionFilter(e.target.value || null)}
                >
                  <option value="">Toutes actions</option>
                  {availableActions.map((a) => <option key={a} value={a}>{a}</option>)}
                </select>
              </div>
            </div>

            <ScrollArea className="flex-1">
              {!selected ? (
                <div className="p-8 text-center text-muted-foreground text-sm">
                  Sélectionnez un rôle pour éditer ses permissions.
                </div>
              ) : (
                <PermissionTree
                  domains={domains}
                  modules={modules}
                  resources={resources}
                  perms={filteredPerms}
                  allPermsCount={perms.length}
                  state={permStateFor(selected.code)}
                  onToggle={(perm) => {
                    const st = permStateFor(selected.code).get(perm);
                    const cur: "grant" | "deny" | "clear" =
                      st?.direct === true ? "deny" : st?.direct === false ? "clear" : "grant";
                    savePerm(selected.code, perm, cur);
                  }}
                  onBulkModule={(m, grant) => bulkSetModule(selected.code, m, grant)}
                  expandedDomains={expandedDomains}
                  expandedModules={expandedModules}
                  toggleDomain={toggleDomain}
                  toggleModule={toggleModule}
                />
              )}
            </ScrollArea>
          </Card>

          {/* Colonne détails */}
          <Card className="col-span-3 flex flex-col min-h-0">
            {!selected ? (
              <div className="p-8 text-center text-muted-foreground text-sm">Aucun rôle sélectionné</div>
            ) : (
              <RoleDetailsPanel
                role={selected}
                roles={roles}
                parents={parentsByRole.get(selected.code) ?? []}
                onToggleParent={(p) => toggleParent(selected.code, p)}
                users={(usersByRole.get(selected.code) ?? [])
                  .map((id) => profiles.find((p) => p.id === id))
                  .filter((x): x is Profile => !!x)}
                allProfiles={profiles.filter((p) => !(usersByRole.get(selected.code) ?? []).includes(p.id))}
                onAssignUser={(uid) => assignUser(selected.code, uid)}
                onRevokeUser={(uid) => revokeUser(selected.code, uid)}
                onDelete={() => deleteRole(selected.code)}
                permByCode={permByCode}
                grantsCount={rolePerms.filter((x) => x.role_code === selected.code && x.granted).length}
                denyCount={rolePerms.filter((x) => x.role_code === selected.code && !x.granted).length}
                inheritedCount={(() => {
                  const chain = closureOf(selected.code);
                  chain.delete(selected.code);
                  return new Set(rolePerms.filter((x) => chain.has(x.role_code) && x.granted).map((x) => x.perm_code)).size;
                })()}
              />
            )}
          </Card>
        </div>
      )}

      <DiagnosticDialog
        open={diagOpen}
        onOpenChange={setDiagOpen}
        roleByCode={roleByCode}
        onGoRole={(code) => { setSelectedRole(code); setDiagOpen(false); }}
      />
    </div>
  );
}

// ---- permission tree ----
function PermissionTree(props: {
  domains: Domain[]; modules: Module[]; resources: Resource[]; perms: Permission[];
  allPermsCount: number;
  state: Map<string, { direct?: boolean; inheritedGrant?: boolean; deniedInChain: boolean }>;
  onToggle: (permCode: string) => void;
  onBulkModule: (moduleCode: string, grantAll: boolean) => void;
  expandedDomains: Set<string>; expandedModules: Set<string>;
  toggleDomain: (c: string) => void; toggleModule: (c: string) => void;
}) {
  const { domains, modules, resources, perms, state, onToggle, onBulkModule,
    expandedDomains, expandedModules, toggleDomain, toggleModule } = props;

  const permsByResource = useMemo(() => {
    const m = new Map<string, Permission[]>();
    perms.forEach((p) => {
      const arr = m.get(p.resource_code) ?? [];
      arr.push(p);
      m.set(p.resource_code, arr);
    });
    return m;
  }, [perms]);

  const resourcesByModule = useMemo(() => {
    const m = new Map<string, Resource[]>();
    resources.forEach((r) => {
      const arr = m.get(r.module_code) ?? [];
      arr.push(r);
      m.set(r.module_code, arr);
    });
    return m;
  }, [resources]);

  const modulesByDomain = useMemo(() => {
    const m = new Map<string, Module[]>();
    modules.forEach((mm) => {
      const arr = m.get(mm.domain_code) ?? [];
      arr.push(mm);
      m.set(mm.domain_code, arr);
    });
    return m;
  }, [modules]);

  return (
    <div className="p-2 space-y-1">
      {domains.map((d) => {
        const mods = modulesByDomain.get(d.code) ?? [];
        // filter modules to those with visible perms
        const visibleMods = mods.filter((mm) => {
          const rs = resourcesByModule.get(mm.code) ?? [];
          return rs.some((r) => (permsByResource.get(r.code) ?? []).length > 0);
        });
        if (visibleMods.length === 0) return null;

        const totalPerms = visibleMods.reduce((acc, mm) => {
          const rs = resourcesByModule.get(mm.code) ?? [];
          return acc + rs.reduce((a, r) => a + (permsByResource.get(r.code)?.length ?? 0), 0);
        }, 0);
        const grantedPerms = visibleMods.reduce((acc, mm) => {
          const rs = resourcesByModule.get(mm.code) ?? [];
          return acc + rs.reduce((a, r) => a + (permsByResource.get(r.code) ?? []).filter((p) => {
            const st = state.get(p.code);
            return st?.direct === true || st?.inheritedGrant;
          }).length, 0);
        }, 0);
        const pct = totalPerms > 0 ? (grantedPerms / totalPerms) * 100 : 0;
        const isOpen = expandedDomains.has(d.code);

        return (
          <div key={d.code} className="border rounded-md">
            <button
              onClick={() => toggleDomain(d.code)}
              className="w-full flex items-center gap-2 p-2 hover:bg-muted rounded-t-md"
            >
              {isOpen ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
              <span className="font-semibold text-sm flex-1 text-left">{d.label}</span>
              <span className="text-xs text-muted-foreground">{grantedPerms}/{totalPerms}</span>
              <div className="w-16"><Progress value={pct} className="h-1.5" /></div>
            </button>

            {isOpen && (
              <div className="p-2 space-y-1 border-t bg-muted/30">
                {visibleMods.map((mm) => {
                  const rs = resourcesByModule.get(mm.code) ?? [];
                  const modPerms = rs.flatMap((r) => permsByResource.get(r.code) ?? []);
                  const modGranted = modPerms.filter((p) => {
                    const st = state.get(p.code);
                    return st?.direct === true || st?.inheritedGrant;
                  }).length;
                  const modOpen = expandedModules.has(mm.code);
                  return (
                    <div key={mm.code} className="border rounded bg-background">
                      <div className="flex items-center gap-2 p-1.5">
                        <button onClick={() => toggleModule(mm.code)} className="flex items-center gap-1 flex-1 text-left hover:text-primary">
                          {modOpen ? <ChevronDown className="h-3.5 w-3.5" /> : <ChevronRight className="h-3.5 w-3.5" />}
                          <span className="text-sm font-medium">{mm.label}</span>
                          <span className="text-[11px] text-muted-foreground">({modGranted}/{modPerms.length})</span>
                        </button>
                        <Button size="sm" variant="ghost" className="h-6 text-xs px-1.5"
                          onClick={() => onBulkModule(mm.code, true)}>Tout</Button>
                        <Button size="sm" variant="ghost" className="h-6 text-xs px-1.5"
                          onClick={() => onBulkModule(mm.code, false)}>Aucun</Button>
                      </div>
                      {modOpen && (
                        <div className="p-2 pt-0 space-y-1">
                          {rs.map((r) => {
                            const rperms = permsByResource.get(r.code) ?? [];
                            if (rperms.length === 0) return null;
                            return (
                              <div key={r.code} className="pl-3 py-1">
                                <div className="text-xs font-semibold text-muted-foreground mb-1">{r.label}</div>
                                <div className="flex flex-wrap gap-1.5">
                                  {rperms.map((p) => {
                                    const st = state.get(p.code);
                                    const direct = st?.direct;
                                    const inherited = st?.inheritedGrant;
                                    const denied = st?.deniedInChain && direct !== true;
                                    const cls =
                                      direct === true ? "border-emerald-500 bg-emerald-500/10" :
                                      direct === false ? "border-red-500 bg-red-500/10" :
                                      inherited ? "border-blue-500/50 bg-blue-500/5 border-dashed" :
                                      "border-border bg-muted/40";
                                    return (
                                      <button
                                        key={p.code}
                                        onClick={() => onToggle(p.code)}
                                        title={p.code + (denied ? " (refusé en amont)" : inherited ? " (hérité)" : "")}
                                        className={`text-xs px-2 py-1 rounded border ${cls} hover:opacity-80 transition inline-flex items-center gap-1`}
                                      >
                                        {direct === true && <CheckCircle2 className="h-3 w-3 text-emerald-600" />}
                                        {direct === false && <XCircle className="h-3 w-3 text-red-600" />}
                                        <span className={`px-1 rounded text-[10px] ${actionColor(p.action)}`}>{p.action}</span>
                                        <span className="text-foreground">{p.label}</span>
                                      </button>
                                    );
                                  })}
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ---- details panel ----
function RoleDetailsPanel(props: {
  role: Role;
  roles: Role[];
  parents: string[];
  onToggleParent: (code: string) => void;
  users: Profile[];
  allProfiles: Profile[];
  onAssignUser: (id: string) => void;
  onRevokeUser: (id: string) => void;
  onDelete: () => void;
  permByCode: Map<string, Permission>;
  grantsCount: number;
  denyCount: number;
  inheritedCount: number;
}) {
  const { role, roles, parents, onToggleParent, users, allProfiles, onAssignUser,
    onRevokeUser, onDelete, grantsCount, denyCount, inheritedCount } = props;
  const [tab, setTab] = useState<"info" | "parents" | "users" | "audit">("info");
  const [assignQuery, setAssignQuery] = useState("");
  const [audit, setAudit] = useState<AuditRow[]>([]);
  const [auditLoading, setAuditLoading] = useState(false);
  const [auditActionFilter, setAuditActionFilter] = useState<string | null>(null);
  const filteredAudit = useMemo(
    () => audit.filter((a) => !auditActionFilter || a.action === auditActionFilter),
    [audit, auditActionFilter],
  );

  const loadAudit = useCallback(async () => {
    setAuditLoading(true);
    try {
      const { data, error } = await supabase.from("rbac2_audit")
        .select("*")
        .or(`target_id.eq.${role.code},target_type.eq.rbac2_role_perms`)
        .order("at", { ascending: false })
        .limit(50);
      if (error) throw error;
      setAudit((data ?? []).filter((r: AuditRow) => {
        const after = r.after as Record<string, unknown> | null;
        const before = r.before as Record<string, unknown> | null;
        return (after?.role_code === role.code) || (before?.role_code === role.code) ||
               r.target_id === role.code;
      }) as AuditRow[]);
    } catch (e) {
      toast.error(friendlyError(e));
    } finally {
      setAuditLoading(false);
    }
  }, [role.code]);

  useEffect(() => { if (tab === "audit") loadAudit(); }, [tab, loadAudit]);

  const filteredProfiles = allProfiles.filter((p) => {
    const q = assignQuery.toLowerCase().trim();
    if (!q) return true;
    return (p.email ?? "").toLowerCase().includes(q) ||
      (p.nom ?? "").toLowerCase().includes(q) ||
      (p.prenoms ?? "").toLowerCase().includes(q);
  }).slice(0, 20);

  return (
    <div className="flex flex-col min-h-0 h-full">
      <div className="p-3 border-b">
        <div className="flex items-center justify-between">
          <div className="min-w-0">
            <div className="font-semibold truncate">{role.label}</div>
            <div className="text-xs text-muted-foreground truncate">{role.code}</div>
          </div>
          {!role.is_system && (
            <Button size="icon" variant="ghost" className="h-7 w-7 text-destructive" onClick={onDelete}>
              <Trash2 className="h-4 w-4" />
            </Button>
          )}
        </div>
        <div className="grid grid-cols-3 gap-2 mt-3 text-center">
          <div className="bg-emerald-500/10 rounded p-1.5">
            <div className="text-sm font-bold text-emerald-600">{grantsCount}</div>
            <div className="text-[10px] text-muted-foreground">Accordées</div>
          </div>
          <div className="bg-red-500/10 rounded p-1.5">
            <div className="text-sm font-bold text-red-600">{denyCount}</div>
            <div className="text-[10px] text-muted-foreground">Refusées</div>
          </div>
          <div className="bg-blue-500/10 rounded p-1.5">
            <div className="text-sm font-bold text-blue-600">{inheritedCount}</div>
            <div className="text-[10px] text-muted-foreground">Héritées</div>
          </div>
        </div>
      </div>

      <div className="flex border-b text-xs">
        {(["info", "parents", "users", "audit"] as const).map((t) => (
          <button key={t} onClick={() => setTab(t)}
            className={`flex-1 py-2 font-medium ${tab === t ? "border-b-2 border-primary text-primary" : "text-muted-foreground"}`}>
            {t === "info" ? "Résumé" : t === "parents" ? "Héritage" : t === "users" ? `Utilisateurs (${users.length})` : "Audit"}
          </button>
        ))}
      </div>

      <ScrollArea className="flex-1">
        <div className="p-3">
          {tab === "info" && (
            <div className="text-sm space-y-2">
              <div className="text-muted-foreground text-xs">Description</div>
              <div>{role.description || <span className="italic text-muted-foreground">Aucune</span>}</div>
              <Separator />
              <div className="text-muted-foreground text-xs">Rôle système</div>
              <div>{role.is_system ? "Oui" : "Non"}</div>
              <Separator />
              <div className="text-muted-foreground text-xs">Parents ({parents.length})</div>
              <div className="flex flex-wrap gap-1">
                {parents.length === 0 && <span className="italic text-xs text-muted-foreground">Aucun</span>}
                {parents.map((p) => (
                  <Badge key={p} variant="secondary" className="text-xs">
                    <GitBranch className="h-3 w-3 mr-1" />{p}
                  </Badge>
                ))}
              </div>
            </div>
          )}

          {tab === "parents" && (
            <div className="space-y-1">
              <div className="text-xs text-muted-foreground mb-2">Cochez les rôles dont ce rôle hérite (héritage multiple, union des permissions).</div>
              {roles.filter((r) => r.code !== role.code).map((r) => {
                const checked = parents.includes(r.code);
                return (
                  <label key={r.code} className="flex items-center gap-2 p-1.5 rounded hover:bg-muted cursor-pointer">
                    <Checkbox checked={checked} onCheckedChange={() => onToggleParent(r.code)} />
                    <span className="text-sm flex-1">{r.label}</span>
                    <span className="text-[10px] text-muted-foreground">{r.code}</span>
                  </label>
                );
              })}
            </div>
          )}

          {tab === "users" && (
            <div className="space-y-3">
              <div className="space-y-1">
                {users.length === 0 && <div className="italic text-sm text-muted-foreground">Aucun utilisateur assigné.</div>}
                {users.map((u) => (
                  <div key={u.id} className="flex items-center gap-2 p-1.5 rounded border bg-background">
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium truncate">{u.prenoms ?? ""} {u.nom ?? ""}</div>
                      <div className="text-xs text-muted-foreground truncate">{u.email}</div>
                    </div>
                    <Button size="icon" variant="ghost" className="h-6 w-6" onClick={() => onRevokeUser(u.id)}>
                      <X className="h-4 w-4" />
                    </Button>
                  </div>
                ))}
              </div>

              <Dialog>
                <DialogTrigger asChild>
                  <Button size="sm" variant="outline" className="w-full">
                    <UserPlus className="h-4 w-4 mr-2" />Attribuer à un utilisateur
                  </Button>
                </DialogTrigger>
                <DialogContent className="max-w-md">
                  <DialogHeader>
                    <DialogTitle>Attribuer « {role.label} »</DialogTitle>
                    <DialogDescription>
                      L'utilisateur obtiendra immédiatement les {grantsCount + inheritedCount} permissions du rôle.
                    </DialogDescription>
                  </DialogHeader>
                  <Input placeholder="Rechercher (nom, email)…" value={assignQuery}
                    onChange={(e) => setAssignQuery(e.target.value)} />
                  <ScrollArea className="max-h-72">
                    <div className="space-y-1">
                      {filteredProfiles.length === 0 && (
                        <div className="text-sm text-muted-foreground italic p-2">Aucun résultat</div>
                      )}
                      {filteredProfiles.map((u) => (
                        <button key={u.id}
                          onClick={() => onAssignUser(u.id)}
                          className="w-full text-left flex items-center gap-2 p-2 rounded hover:bg-muted">
                          <div className="flex-1 min-w-0">
                            <div className="text-sm font-medium truncate">{u.prenoms ?? ""} {u.nom ?? ""}</div>
                            <div className="text-xs text-muted-foreground truncate">{u.email}</div>
                          </div>
                          <Plus className="h-4 w-4" />
                        </button>
                      ))}
                    </div>
                  </ScrollArea>
                </DialogContent>
              </Dialog>
            </div>
          )}

          {tab === "audit" && (
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <select
                  className="h-8 rounded-md border bg-background px-2 text-xs flex-1"
                  onChange={(e) => setAuditActionFilter(e.target.value || null)}
                  value={auditActionFilter ?? ""}
                >
                  <option value="">Toutes actions</option>
                  <option value="INSERT">Ajout</option>
                  <option value="UPDATE">Modification</option>
                  <option value="DELETE">Suppression</option>
                </select>
                <Button size="sm" variant="outline" onClick={() => {
                  const rows = [["date", "action", "cible", "acteur", "avant", "après"]];
                  filteredAudit.forEach((a) => rows.push([
                    a.at, a.action, a.target_type, a.actor_id ?? "",
                    JSON.stringify(a.before ?? ""), JSON.stringify(a.after ?? ""),
                  ]));
                  const csv = rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(",")).join("\n");
                  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
                  const url = URL.createObjectURL(blob);
                  const a = document.createElement("a");
                  a.href = url; a.download = `audit-${role.code}-${new Date().toISOString().slice(0, 10)}.csv`;
                  a.click(); URL.revokeObjectURL(url);
                }}>
                  <Download className="h-3 w-3 mr-1" />CSV
                </Button>
              </div>
              {auditLoading && <div className="text-sm text-muted-foreground">Chargement…</div>}
              {!auditLoading && filteredAudit.length === 0 && (
                <div className="italic text-sm text-muted-foreground">Aucun événement.</div>
              )}
              {filteredAudit.map((a) => (
                <div key={a.id} className="text-xs border-l-2 border-primary pl-2 py-1">
                  <div className="flex items-center gap-2">
                    <HistoryIcon className="h-3 w-3 text-muted-foreground" />
                    <span className="font-medium">{a.action}</span>
                    <span className="text-muted-foreground">· {a.target_type}</span>
                  </div>
                  <div className="text-muted-foreground">{new Date(a.at).toLocaleString("fr-FR")}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </ScrollArea>
    </div>
  );
}

// ---- create role dialog ----
function CreateRoleDialog({ onCreate }: { onCreate: (code: string, label: string, description: string) => Promise<void> }) {
  const [open, setOpen] = useState(false);
  const [code, setCode] = useState("");
  const [label, setLabel] = useState("");
  const [description, setDescription] = useState("");
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button><Plus className="h-4 w-4 mr-2" />Nouveau rôle</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Créer un nouveau rôle</DialogTitle>
          <DialogDescription>
            Le code doit être unique (ex : <code>chef_atelier</code>). Il servira aussi de référence dans le code de l'application.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3">
          <div>
            <Label>Code</Label>
            <Input value={code} onChange={(e) => setCode(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, "_"))}
              placeholder="ex: chef_atelier" />
          </div>
          <div>
            <Label>Libellé</Label>
            <Input value={label} onChange={(e) => setLabel(e.target.value)} placeholder="ex: Chef d'atelier" />
          </div>
          <div>
            <Label>Description (optionnel)</Label>
            <Textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={2} />
          </div>
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={() => setOpen(false)}>Annuler</Button>
          <Button disabled={!code || !label} onClick={async () => {
            await onCreate(code, label, description);
            setOpen(false); setCode(""); setLabel(""); setDescription("");
          }}>Créer</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ---- Diagnostic dialog ----
type DiagnosticReport = {
  roles_sans_permission: Array<{ code: string; label: string }>;
  roles_sans_utilisateur: Array<{ code: string; label: string }>;
  grants_orphelins: Array<{ role: string; perm: string }>;
  dependances_manquantes: Array<{ role: string; perm: string; manque: string }>;
  ressources_sans_permission: Array<{ code: string; label: string }>;
  cycles_heritage: Array<{ role: string }>;
  generated_at: string;
};

function DiagnosticDialog(props: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  roleByCode: Map<string, Role>;
  onGoRole: (code: string) => void;
}) {
  const { open, onOpenChange, roleByCode, onGoRole } = props;
  const [loading, setLoading] = useState(false);
  const [report, setReport] = useState<DiagnosticReport | null>(null);

  const run = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("rbac2_diagnose");
      if (error) throw error;
      setReport(data as unknown as DiagnosticReport);
    } catch (e) {
      toast.error(friendlyError(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { if (open) run(); }, [open, run]);

  const sections: Array<{ key: keyof DiagnosticReport; title: string; render: (row: unknown) => React.ReactNode }> = [
    {
      key: "roles_sans_permission",
      title: "Rôles sans permission accordée",
      render: (row) => {
        const r = row as { code: string; label: string };
        return (
          <button className="text-left hover:underline" onClick={() => onGoRole(r.code)}>
            {r.label} <span className="text-muted-foreground">({r.code})</span>
          </button>
        );
      },
    },
    {
      key: "roles_sans_utilisateur",
      title: "Rôles sans utilisateur",
      render: (row) => {
        const r = row as { code: string; label: string };
        return (
          <button className="text-left hover:underline" onClick={() => onGoRole(r.code)}>
            {r.label} <span className="text-muted-foreground">({r.code})</span>
          </button>
        );
      },
    },
    {
      key: "dependances_manquantes",
      title: "Dépendances manquantes",
      render: (row) => {
        const r = row as { role: string; perm: string; manque: string };
        const label = roleByCode.get(r.role)?.label ?? r.role;
        return (
          <span>
            <button className="hover:underline font-medium" onClick={() => onGoRole(r.role)}>{label}</button>
            {" — "}<code className="text-[11px]">{r.perm}</code> nécessite <code className="text-[11px]">{r.manque}</code>
          </span>
        );
      },
    },
    {
      key: "grants_orphelins",
      title: "Grants orphelins (permission supprimée du catalogue)",
      render: (row) => {
        const r = row as { role: string; perm: string };
        return <span><code>{r.role}</code> → <code>{r.perm}</code></span>;
      },
    },
    {
      key: "ressources_sans_permission",
      title: "Ressources sans permission",
      render: (row) => {
        const r = row as { code: string; label: string };
        return <span>{r.label} <code className="text-[11px]">({r.code})</code></span>;
      },
    },
    {
      key: "cycles_heritage",
      title: "Cycles d'héritage détectés",
      render: (row) => {
        const r = row as { role: string };
        return <code className="text-red-600">{r.role}</code>;
      },
    },
  ];

  const totalIssues = report
    ? sections.reduce((n, s) => n + ((report[s.key] as unknown[])?.length ?? 0), 0)
    : 0;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Stethoscope className="h-5 w-5 text-primary" />
            Diagnostic RBAC
            {report && (
              <Badge variant={totalIssues > 0 ? "destructive" : "secondary"} className="ml-2">
                {totalIssues} anomalie{totalIssues > 1 ? "s" : ""}
              </Badge>
            )}
          </DialogTitle>
          <DialogDescription>
            Analyse du catalogue, des rôles, des attributions et des dépendances entre permissions.
          </DialogDescription>
        </DialogHeader>

        {loading && <div className="py-8 text-center text-sm text-muted-foreground">Analyse en cours…</div>}
        {!loading && report && totalIssues === 0 && (
          <div className="py-6 text-center text-emerald-600 flex flex-col items-center gap-2">
            <CheckCircle2 className="h-8 w-8" />
            <div className="font-medium">Aucune anomalie détectée.</div>
          </div>
        )}
        {!loading && report && totalIssues > 0 && (
          <ScrollArea className="max-h-[60vh]">
            <div className="space-y-3 pr-3">
              {sections.map((s) => {
                const rows = (report[s.key] as unknown[]) ?? [];
                if (rows.length === 0) return null;
                return (
                  <div key={s.key} className="border rounded-md">
                    <div className="px-3 py-2 border-b bg-muted/40 flex items-center gap-2 text-sm font-medium">
                      <AlertTriangle className="h-4 w-4 text-amber-600" />
                      {s.title}
                      <Badge variant="outline" className="ml-auto">{rows.length}</Badge>
                    </div>
                    <ul className="p-2 space-y-1 text-sm">
                      {rows.slice(0, 40).map((row, i) => (
                        <li key={i} className="px-2 py-1 rounded hover:bg-muted">{s.render(row)}</li>
                      ))}
                      {rows.length > 40 && (
                        <li className="px-2 py-1 text-xs italic text-muted-foreground">
                          … {rows.length - 40} autres non affichés
                        </li>
                      )}
                    </ul>
                  </div>
                );
              })}
            </div>
          </ScrollArea>
        )}

        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>Fermer</Button>
          <Button variant="outline" onClick={run} disabled={loading}>Relancer</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
