import { memo, useDeferredValue, useMemo, useState } from "react";
import { AlertTriangle, CheckCircle2, Loader2, Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
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
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { ResponsiveTable } from "@/components/layout/ResponsiveTable";
import {
  MODULE_GROUPS,
  ACTIONS,
  EXTRA_PERMISSIONS,
  type ExtraPermission,
  type PermissionCategorie,
} from "@/lib/rbac-catalog";
import {
  useRolesQuery,
  useRolePermissionsQuery,
  useTogglePermission,
  usePermissionsCatalogQuery,
  useBulkSetPermissions,
} from "@/hooks/use-roles-permissions";
import { Button } from "@/components/ui/button";
import { groups } from "@/components/layout/sidebar/nav-data";
import {
  diagnoseExpectedMenuGroups,
  filterNavGroupsByPermissions,
} from "@/lib/rbac-menu-diagnostics";

const actionOrder = new Map<string, number>(ACTIONS.map((a, index) => [a.code, index]));

const CATEGORIE_META: Record<
  PermissionCategorie,
  { label: string; className: string }
> = {
  workflow:       { label: "Workflow",       className: "bg-blue-100 text-blue-800 border-blue-200" },
  sensible:       { label: "Sensible",       className: "bg-red-100 text-red-800 border-red-200" },
  administration: { label: "Administration", className: "bg-purple-100 text-purple-800 border-purple-200" },
  declaration:    { label: "Déclaration",    className: "bg-amber-100 text-amber-800 border-amber-200" },
  export:         { label: "Export",         className: "bg-emerald-100 text-emerald-800 border-emerald-200" },
  consultation:   { label: "Consultation",   className: "bg-slate-100 text-slate-700 border-slate-200" },
};

const EXTRA_BY_SOUS_MODULE = EXTRA_PERMISSIONS.reduce((acc, p) => {
  const arr = acc.get(p.sousModule) ?? [];
  arr.push(p);
  acc.set(p.sousModule, arr);
  return acc;
}, new Map<string, ExtraPermission[]>());

/**
 * Case permission avec état visuel :
 *  - vert   : accordée
 *  - rouge  : refusée (case décochée mais permission existante)
 *  - orange : sauvegarde en cours
 *  - bleu   : héritée du rôle parent
 */
function PermissionCell({
  code,
  granted,
  inherited,
  pending,
  onToggle,
}: {
  code: string;
  granted: boolean;
  inherited: boolean;
  pending: boolean;
  onToggle: (next: boolean) => void;
}) {
  const ring = pending
    ? "ring-2 ring-orange-400"
    : inherited && !granted
      ? "ring-2 ring-blue-400"
      : granted
        ? "ring-2 ring-emerald-500"
        : "ring-1 ring-red-200";
  return (
    <span
      className={`inline-flex h-5 w-5 items-center justify-center rounded ${ring} transition-colors`}
      title={
        pending
          ? "Sauvegarde en cours…"
          : inherited && !granted
            ? "Héritée du rôle parent"
            : granted
              ? "Permission accordée"
              : "Permission refusée"
      }
    >
      <Checkbox
        checked={granted}
        disabled={pending}
        onCheckedChange={(v) => onToggle(!!v)}
        aria-label={code}
      />
    </span>
  );
}

const MemoPermissionCell = memo(PermissionCell);

type MatrixPermission = {
  code: string;
  action: string;
};

type MatrixSousModule = {
  code: string;
  libelle: string;
  permissions: MatrixPermission[];
  codes: Set<string>;
};

type MatrixModule = {
  module: string;
  sousModules: MatrixSousModule[];
  codes: string[];
};

/**
 * Ligne de matrice mémoïsée : ne se re-render que quand l'état de CE
 * sous-module change (grantedKey / inheritedKey / pendingKey comparés
 * par égalité de chaîne — comparaison peu coûteuse).
 */
type MatrixRowProps = {
  sm: MatrixSousModule;
  visibleActions: typeof ACTIONS;
  grantedKey: string;
  inheritedKey: string;
  pendingKey: string;
  onToggleCell: (code: string, next: boolean) => void;
};

const MatrixRow = memo(function MatrixRow({
  sm,
  visibleActions,
  grantedKey,
  inheritedKey,
  pendingKey,
  onToggleCell,
}: MatrixRowProps) {
  const grantedSet = useMemo(() => new Set(grantedKey ? grantedKey.split("|") : []), [grantedKey]);
  const inheritedSet = useMemo(() => new Set(inheritedKey ? inheritedKey.split("|") : []), [inheritedKey]);
  const pendingSet = useMemo(() => new Set(pendingKey ? pendingKey.split("|") : []), [pendingKey]);
  return (
    <TableRow>
      <TableCell className="font-medium select-none">
        {sm.libelle}
      </TableCell>
      {visibleActions.map((a) => {
        const code = `${sm.code}.${a.code}`;
        const exists = sm.codes.has(code);
        return (
          <TableCell key={a.code} className="text-center">
            {exists ? (
              <MemoPermissionCell
                code={code}
                granted={grantedSet.has(code)}
                inherited={inheritedSet.has(code)}
                pending={pendingSet.has(code)}
                onToggle={(next) => onToggleCell(code, next)}
              />
            ) : (
              <span className="text-muted-foreground/40">—</span>
            )}
          </TableCell>
        );
      })}
    </TableRow>
  );
});

export function MatrixTab({
  roleId: controlledRoleId,
  onRoleChange,
  hideRoleSelect = false,
}: {
  roleId?: string | null;
  onRoleChange?: (id: string) => void;
  hideRoleSelect?: boolean;
} = {}) {
  const rolesQ = useRolesQuery();
  const [internalRoleId, setInternalRoleId] = useState<string | null>(null);
  const selectedRoleId = controlledRoleId ?? internalRoleId;
  const setSelectedRoleId = (id: string) => {
    if (onRoleChange) onRoleChange(id);
    else setInternalRoleId(id);
  };
  const [search, setSearch] = useState("");
  const deferredSearch = useDeferredValue(search);
  const [moduleFilter, setModuleFilter] = useState<string>("all");
  const [actionFilter, setActionFilter] = useState<string>("all");

  const activeRoles = useMemo(() => rolesQ.data?.filter((r) => r.actif) ?? [], [rolesQ.data]);
  const currentRoleId = selectedRoleId ?? activeRoles[0]?.role_id ?? null;
  const currentRole = useMemo(
    () => rolesQ.data?.find((r) => r.role_id === currentRoleId) ?? null,
    [rolesQ.data, currentRoleId],
  );
  const parentRoleId = currentRole?.hierite_de ?? null;

  const rpQ = useRolePermissionsQuery(currentRoleId);
  const parentRpQ = useRolePermissionsQuery(parentRoleId);
  const permsQ = usePermissionsCatalogQuery();
  const toggle = useTogglePermission(currentRoleId);
  const bulk = useBulkSetPermissions(currentRoleId);
  const [pendingCodes, setPendingCodes] = useState<Set<string>>(new Set());

  const markPending = (codes: string[], on: boolean) => {
    setPendingCodes((prev) => {
      const next = new Set(prev);
      for (const c of codes) (on ? next.add(c) : next.delete(c));
      return next;
    });
  };

  const permissionByCode = useMemo(
    () => new Map((permsQ.data ?? []).map((permission) => [permission.code, permission])),
    [permsQ.data],
  );

  const expandToggleCodes = (code: string, next: boolean) => {
    const permission = permissionByCode.get(code);
    if (!permission?.sous_module) return [code];

    if (next && permission.action !== "voir") {
      const viewCode = `${permission.sous_module}.voir`;
      return permissionByCode.has(viewCode) ? [code, viewCode] : [code];
    }

    if (!next && permission.action === "voir") {
      return Array.from(permissionByCode.values())
        .filter((candidate) => candidate.sous_module === permission.sous_module)
        .map((candidate) => candidate.code);
    }

    return [code];
  };

  const toggleOne = (code: string, next: boolean) => {
    const codes = expandToggleCodes(code, next);
    if (codes.length > 1) {
      bulk.mutate({ codes, next });
      return;
    }
    toggle.mutate({ code, next });
  };

  const moduleGroups = useMemo<MatrixModule[]>(() => {
    const permissionsBySousModule = new Map<string, MatrixPermission[]>();

    for (const permission of permsQ.data ?? []) {
      const sousModuleCode = permission.sous_module ?? permission.code.split(".")[0] ?? permission.code;
      const permissions = permissionsBySousModule.get(sousModuleCode) ?? [];

      permissions.push({ code: permission.code, action: permission.action });
      permissionsBySousModule.set(sousModuleCode, permissions);
    }

    return MODULE_GROUPS.map((group) => {
      const sousModules = group.sousModules
        .map((sm) => {
          const permissions = [...(permissionsBySousModule.get(sm.code) ?? [])].sort(
            (a, b) =>
              (actionOrder.get(a.action) ?? Number.MAX_SAFE_INTEGER) -
              (actionOrder.get(b.action) ?? Number.MAX_SAFE_INTEGER),
          );

          return {
            code: sm.code,
            libelle: sm.libelle,
            permissions,
            codes: new Set(permissions.map((p) => p.code)),
          };
        })
        .filter((sm) => sm.permissions.length > 0);

      return {
        module: group.module,
        sousModules,
        codes: sousModules.flatMap((sm) => sm.permissions.map((p) => p.code)),
      };
    }).filter((group) => group.codes.length > 0);
  }, [permsQ.data]);

  const granted = useMemo(() => {
    const s = new Set<string>();
    (rpQ.data ?? []).forEach((r) => {
      if (r.accorde) s.add(r.permission_code);
    });
    return s;
  }, [rpQ.data]);

  const inherited = useMemo(() => {
    const s = new Set<string>();
    (parentRpQ.data ?? []).forEach((r) => {
      if (r.accorde) s.add(r.permission_code);
    });
    return s;
  }, [parentRpQ.data]);

  const effectivePermissions = useMemo(() => {
    const permissions = new Set(granted);
    inherited.forEach((permission) => permissions.add(permission));
    return permissions;
  }, [granted, inherited]);

  const menuDiagnostics = useMemo(
    () =>
      diagnoseExpectedMenuGroups(
        effectivePermissions,
        filterNavGroupsByPermissions(effectivePermissions, groups),
      ),
    [effectivePermissions],
  );

  const totals = useMemo(() => {
    const all = (permsQ.data ?? []).length;
    const accorded = granted.size;
    const refused = Math.max(0, all - accorded);
    const pct = all === 0 ? 0 : Math.round((accorded / all) * 100);
    return { all, accorded, refused, pct };
  }, [permsQ.data, granted]);

  const filter = deferredSearch.trim().toLowerCase();
  const visibleActions = useMemo(
    () => (actionFilter === "all" ? ACTIONS : ACTIONS.filter((a) => a.code === actionFilter)),
    [actionFilter],
  );

  /**
   * État par sous-module sérialisé en chaînes stables : permet à `MatrixRow`
   * (mémoïsée) de se re-render uniquement quand SA propre ligne change,
   * même si `granted` (Set global) est recréé à chaque mutation.
   */
  const rowKeys = useMemo(() => {
    const m = new Map<string, { grantedKey: string; inheritedKey: string; pendingKey: string }>();
    for (const g of moduleGroups) {
      for (const sm of g.sousModules) {
        const gk: string[] = [];
        const ik: string[] = [];
        const pk: string[] = [];
        for (const p of sm.permissions) {
          if (granted.has(p.code)) gk.push(p.code);
          if (inherited.has(p.code)) ik.push(p.code);
          if (pendingCodes.has(p.code)) pk.push(p.code);
        }
        m.set(sm.code, {
          grantedKey: gk.join("|"),
          inheritedKey: ik.join("|"),
          pendingKey: pk.join("|"),
        });
      }
    }
    return m;
  }, [moduleGroups, granted, inherited, pendingCodes]);

  /** Filtre une liste de codes de permission par l'action visible. */
  const scopeToVisibleActions = (codes: string[]) => {
    if (actionFilter === "all") return codes;
    const suffix = `.${actionFilter}`;
    return codes.filter((c) => c.endsWith(suffix));
  };

  const allBulkCodes = useMemo(
    () => (permsQ.data ?? []).map((permission) => permission.code),
    [permsQ.data],
  );

  return (
    <Card>
      <CardHeader className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div className="flex flex-col gap-1">
          <CardTitle>Matrice des permissions</CardTitle>
          <p className="text-xs text-muted-foreground">
            Sélectionnez un rôle pour ajuster ses permissions par module et action.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {!hideRoleSelect && (
            <Select value={currentRoleId ?? ""} onValueChange={setSelectedRoleId}>
              <SelectTrigger className="w-56">
                <SelectValue placeholder="Choisir un rôle" />
              </SelectTrigger>
              <SelectContent>
                {activeRoles.map((r) => (
                  <SelectItem key={r.role_id} value={r.role_id}>
                    {r.libelle}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
          <div className="relative">
            <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Rechercher…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-48 pl-8"
            />
          </div>
          <Select value={moduleFilter} onValueChange={setModuleFilter}>
            <SelectTrigger className="w-44">
              <SelectValue placeholder="Module" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Tous modules</SelectItem>
              {MODULE_GROUPS.map((g) => (
                <SelectItem key={g.module} value={g.module}>
                  {g.module}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={actionFilter} onValueChange={setActionFilter}>
            <SelectTrigger className="w-44">
              <SelectValue placeholder="Action" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Toutes actions</SelectItem>
              {ACTIONS.map((a) => (
                <SelectItem key={a.code} value={a.code}>
                  {a.libelle}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button
            size="sm"
            variant="default"
            disabled={!currentRoleId || bulk.isPending || permsQ.isLoading}
            onClick={() => {
              if (allBulkCodes.length === 0) return;
              bulk.mutate({ codes: allBulkCodes, next: true });
            }}
          >
            Tout accorder
          </Button>
          <Button
            size="sm"
            variant="outline"
            disabled={!currentRoleId || bulk.isPending || permsQ.isLoading}
            onClick={() => {
              if (allBulkCodes.length === 0) return;
              bulk.mutate({ codes: allBulkCodes, next: false });
            }}
          >
            Tout retirer
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {currentRoleId && (
          <div className="mb-4 flex flex-wrap items-center gap-2 rounded-md border bg-muted/30 p-3 text-sm">
            <Badge className="bg-emerald-100 text-emerald-800 border-emerald-200" variant="outline">
              Accordées : {totals.accorded} / {totals.all}
            </Badge>
            <Badge className="bg-red-100 text-red-800 border-red-200" variant="outline">
              Refusées : {totals.refused} / {totals.all}
            </Badge>
            <Badge className="bg-blue-100 text-blue-800 border-blue-200" variant="outline">
              Progression : {totals.pct}%
            </Badge>
            {parentRoleId && (
              <span className="text-xs text-muted-foreground">
                Rôle parent : {rolesQ.data?.find((r) => r.role_id === parentRoleId)?.libelle} —
                les cases héritées ont un liseré bleu.
              </span>
            )}
            <div className="ml-auto flex items-center gap-3 text-[11px] text-muted-foreground">
              <span className="flex items-center gap-1"><span className="inline-block h-3 w-3 rounded ring-2 ring-emerald-500" /> accordée</span>
              <span className="flex items-center gap-1"><span className="inline-block h-3 w-3 rounded ring-1 ring-red-200" /> refusée</span>
              <span className="flex items-center gap-1"><span className="inline-block h-3 w-3 rounded ring-2 ring-blue-400" /> héritée</span>
            </div>
          </div>
        )}
        {currentRoleId && (
          <div className="mb-4 grid gap-2 md:grid-cols-2">
            {menuDiagnostics.map((diagnostic) => (
              <div
                key={diagnostic.label}
                className="rounded-md border bg-background p-3 text-sm"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2 font-medium">
                    {diagnostic.isOk ? (
                      <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                    ) : (
                      <AlertTriangle className="h-4 w-4 text-amber-600" />
                    )}
                    <span>Diagnostic menu — {diagnostic.label}</span>
                  </div>
                  <Badge variant={diagnostic.isOk ? "outline" : "destructive"}>
                    {diagnostic.sousModulesAffiches} / {diagnostic.permissionsAccordees} visibles
                  </Badge>
                </div>
                {!diagnostic.isOk && (
                  <div className="mt-2 space-y-1 text-xs text-muted-foreground">
                    {diagnostic.missing.length > 0 && (
                      <p>
                        Manquants : {diagnostic.missing.map((item) => item.title).join(", ")}
                      </p>
                    )}
                    {diagnostic.unexpected.length > 0 && (
                      <p>
                        Affichés sans droit : {diagnostic.unexpected.map((item) => item.title).join(", ")}
                      </p>
                    )}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
        {!currentRoleId ? (
          <p className="text-sm text-muted-foreground">Sélectionnez un rôle.</p>
        ) : rpQ.isLoading || permsQ.isLoading ? (
          <div className="flex h-32 items-center justify-center">
            <Loader2 className="h-5 w-5 animate-spin" />
          </div>
        ) : (
          <Accordion
            type="multiple"
            className="w-full"
            defaultValue={moduleGroups.map((m) => m.module)}
          >
            {moduleGroups.map((mod) => {
              if (moduleFilter !== "all" && mod.module !== moduleFilter) return null;
              const allCodes = scopeToVisibleActions(mod.codes);
              const visibleSubs = filter
                ? mod.sousModules.filter(
                    (sm) =>
                      sm.libelle.toLowerCase().includes(filter) ||
                      sm.code.includes(filter) ||
                      mod.module.toLowerCase().includes(filter),
                  )
                : mod.sousModules;
              if (visibleSubs.length === 0) return null;
              const modGranted = allCodes.filter((c) => granted.has(c)).length;

              return (
                <AccordionItem key={mod.module} value={mod.module}>
                  <AccordionTrigger className="hover:no-underline">
                    <div className="flex flex-1 items-center justify-between pr-4">
                      <span className="font-semibold">{mod.module}</span>
                      <div className="flex items-center gap-2">
                        <Badge variant="outline">
                          {modGranted} / {allCodes.length}
                        </Badge>
                        <span
                          role="button"
                          tabIndex={0}
                          onClick={(e) => {
                            e.stopPropagation();
                            e.preventDefault();
                            if (allCodes.length === 0) return;
                            bulk.mutate({ codes: allCodes, next: true });
                          }}
                          onKeyDown={(e) => {
                            if (e.key === "Enter" || e.key === " ") {
                              e.stopPropagation();
                              e.preventDefault();
                              if (allCodes.length === 0) return;
                              bulk.mutate({ codes: allCodes, next: true });
                            }
                          }}
                          className="inline-flex h-7 items-center rounded-md border border-emerald-200 bg-emerald-50 px-2 text-xs font-medium text-emerald-800 hover:bg-emerald-100"
                        >
                          Tout accorder
                        </span>
                        <span
                          role="button"
                          tabIndex={0}
                          onClick={(e) => {
                            e.stopPropagation();
                            e.preventDefault();
                            if (allCodes.length === 0) return;
                            bulk.mutate({ codes: allCodes, next: false });
                          }}
                          onKeyDown={(e) => {
                            if (e.key === "Enter" || e.key === " ") {
                              e.stopPropagation();
                              e.preventDefault();
                              if (allCodes.length === 0) return;
                              bulk.mutate({ codes: allCodes, next: false });
                            }
                          }}
                          className="inline-flex h-7 items-center rounded-md border border-red-200 bg-red-50 px-2 text-xs font-medium text-red-800 hover:bg-red-100"
                        >
                          Tout retirer
                        </span>
                      </div>
                    </div>
                  </AccordionTrigger>
                  <AccordionContent className="[content-visibility:auto] [contain-intrinsic-size:600px]">
                    {(() => {
                      // Précalcul des codes et compteurs par colonne : une seule
                      // passe par module au lieu de N passes dans le JSX.
                      const colInfo = visibleActions.map((a) => {
                        const codes: string[] = [];
                        for (const sm of visibleSubs) {
                          const c = `${sm.code}.${a.code}`;
                          if (sm.codes.has(c)) codes.push(c);
                        }
                        let colGranted = 0;
                        for (const c of codes) if (granted.has(c)) colGranted++;
                        return { action: a, codes, colGranted, allOn: codes.length > 0 && colGranted === codes.length };
                      });
                      return (
                    <ResponsiveTable stickyFirstCol>
                      <Table>
                        <TableHeader>
                          <TableRow>
                            <TableHead className="min-w-[180px] sticky top-0 z-20 bg-background shadow-[inset_0_-1px_0_hsl(var(--border))]">
                              Sous-module
                            </TableHead>
                          {colInfo.map(({ action: a, codes: colCodes, colGranted }) => (
                                <TableHead
                                  key={a.code}
                                  className="text-center text-xs sticky top-0 z-10 bg-background select-none shadow-[inset_0_-1px_0_hsl(var(--border))]"
                                  title={a.libelle}
                                >
                                  <div className="flex flex-col items-center">
                                    <span>{a.libelle}</span>
                                    <span className="text-[10px] text-muted-foreground">
                                      {colGranted}/{colCodes.length}
                                    </span>
                                  </div>
                                </TableHead>
                            ))}
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {visibleSubs.map((sm) => {
                            const keys = rowKeys.get(sm.code) ?? { grantedKey: "", inheritedKey: "", pendingKey: "" };
                            return (
                              <MatrixRow
                                key={sm.code}
                                sm={sm}
                                visibleActions={visibleActions}
                                grantedKey={keys.grantedKey}
                                inheritedKey={keys.inheritedKey}
                                pendingKey={keys.pendingKey}
                                onToggleCell={toggleOne}
                              />
                            );
                          })}
                        </TableBody>
                      </Table>
                    </ResponsiveTable>
                      );
                    })()}
                    {visibleSubs.some((sm) => (EXTRA_BY_SOUS_MODULE.get(sm.code) ?? []).length > 0) && (
                      <div className="mt-3 space-y-2">
                        {visibleSubs.map((sm) => {
                          const extras = EXTRA_BY_SOUS_MODULE.get(sm.code) ?? [];
                          if (extras.length === 0) return null;
                          return (
                            <div
                              key={`extras-${sm.code}`}
                              className="rounded-md border bg-muted/30 p-2"
                            >
                              <div className="mb-1 text-xs font-medium text-muted-foreground">
                                {sm.libelle} — actions métier
                              </div>
                              <div className="flex flex-wrap gap-2">
                                {extras.map((p) => {
                                  const meta = CATEGORIE_META[p.categorie];
                                  const on = granted.has(p.code);
                                  return (
                                    <div
                                      key={p.code}
                                      className="flex items-center gap-2 rounded-md border bg-background px-2 py-1 text-xs"
                                      title={p.code}
                                    >
                                      <PermissionCell
                                        code={p.code}
                                        granted={on}
                                        inherited={inherited.has(p.code)}
                                        pending={pendingCodes.has(p.code)}
                                        onToggle={(next) => toggleOne(p.code, next)}
                                      />
                                      <span>{p.libelle}</span>
                                      <Badge
                                        variant="outline"
                                        className={`text-[10px] ${meta.className}`}
                                      >
                                        {meta.label}
                                      </Badge>
                                    </div>
                                  );
                                })}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </AccordionContent>
                </AccordionItem>
              );
            })}
          </Accordion>
        )}
      </CardContent>
    </Card>
  );
}
