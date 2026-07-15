import { getCurrentUser } from "@/lib/current-user";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import {
  SHORTCUTS_CATALOG,
  MODULE_META,
  findShortcut,
  type ShortcutDef,
} from "@/lib/shortcuts-catalog";
import { usePermissions } from "@/hooks/use-permissions";
import { getRoutePermission } from "@/lib/route-permissions";

export interface StatRow {
  id: string;
  action_key: string;
  module: string | null;
  label: string | null;
  icon: string | null;
  href: string | null;
  usage_count: number;
  last_used_at: string | null;
  pinned: boolean;
  hidden: boolean;
  sort_order: number;
}

export interface DisplayShortcut {
  def: ShortcutDef;
  stat?: StatRow;
  pinned: boolean;
}

const DEFAULT_KEYS = [
  "commandes.create",
  "clients.create",
  "paiements.create",
  "factures.create",
  "livraisons.create",
  "colisage.create",
];

function score(row: StatRow): number {
  const usage = row.usage_count || 0;
  if (!row.last_used_at) return usage;
  const days = (Date.now() - new Date(row.last_used_at).getTime()) / 86_400_000;
  return usage * Math.exp(-days / 30);
}

export function useUserActionStats() {
  return useQuery({
    queryKey: ["user-action-stats"],
    queryFn: async (): Promise<StatRow[]> => {
      const { data, error } = await supabase
        .from("user_action_stats")
        .select(
          "id,action_key,module,label,icon,href,usage_count,last_used_at,pinned,hidden,sort_order",
        );
      if (error) throw error;
      return (data ?? []) as StatRow[];
    },
    staleTime: 60_000,
  });
}

function shortcutAllowed(
  def: ShortcutDef,
  has: (k: string) => boolean,
  isSuperAdmin: boolean,
): boolean {
  if (isSuperAdmin) return true;
  if (def.permission && !has(def.permission)) return false;
  // Also require .voir on the module route (defense in depth)
  const routePerm = getRoutePermission(def.href);
  if (typeof routePerm === "string" && !has(routePerm)) return false;
  return true;
}

export function useSmartShortcuts(limit = 6): { shortcuts: DisplayShortcut[]; isLoading: boolean } {
  const { data: stats, isLoading } = useUserActionStats();
  const { has, isSuperAdmin, isLoading: permsLoading } = usePermissions();
  const rows = stats ?? [];
  const allow = (def: ShortcutDef) => shortcutAllowed(def, has, isSuperAdmin);

  const pinned = rows
    .filter((r) => {
      if (!r.pinned || r.hidden) return false;
      const def = findShortcut(r.action_key);
      return def ? allow(def) : false;
    })
    .sort((a, b) => a.sort_order - b.sort_order)
    .map<DisplayShortcut>((r) => ({ def: findShortcut(r.action_key)!, stat: r, pinned: true }));

  const auto = rows
    .filter((r) => {
      if (r.pinned || r.hidden) return false;
      const def = findShortcut(r.action_key);
      return def ? allow(def) : false;
    })
    .sort((a, b) => score(b) - score(a))
    .slice(0, Math.max(0, limit - pinned.length))
    .map<DisplayShortcut>((r) => ({ def: findShortcut(r.action_key)!, stat: r, pinned: false }));

  let list = [...pinned, ...auto];

  // Empty state fallback: use defaults if user has few stats
  if (list.length < 3) {
    const existing = new Set(list.map((s) => s.def.key));
    const hiddenKeys = new Set(rows.filter((r) => r.hidden).map((r) => r.action_key));
    for (const key of DEFAULT_KEYS) {
      if (list.length >= limit) break;
      if (existing.has(key) || hiddenKeys.has(key)) continue;
      const def = findShortcut(key);
      if (def && allow(def)) list.push({ def, pinned: false });
    }
  }

  return { shortcuts: list.slice(0, limit), isLoading: isLoading || permsLoading };
}

export function useFavoriteModules(limit = 5) {
  const { data: stats, isLoading } = useUserActionStats();
  const { has, isSuperAdmin } = usePermissions();
  const rows = stats ?? [];
  const totals = new Map<string, number>();
  for (const r of rows) {
    if (!r.module) continue;
    totals.set(r.module, (totals.get(r.module) ?? 0) + r.usage_count);
  }
  const list = Array.from(totals.entries())
    .filter(([m]) => MODULE_META[m])
    .filter(([m]) => {
      if (isSuperAdmin) return true;
      const href = MODULE_META[m].href;
      const perm = getRoutePermission(href);
      return typeof perm !== "string" || has(perm);
    })
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([module, count]) => ({ module, count, meta: MODULE_META[module] }));
  return { modules: list, isLoading };
}

export function useShortcutMutations() {
  const qc = useQueryClient();
  const invalidate = () => qc.invalidateQueries({ queryKey: ["user-action-stats"] });

  const upsertRow = async (
    key: string,
    patch: Partial<Pick<StatRow, "pinned" | "hidden" | "sort_order">>,
  ) => {
    const { data: userRes } = await getCurrentUser();
    const uid = userRes.user?.id;
    if (!uid) throw new Error("Non authentifié");
    const def = findShortcut(key);
    const { error } = await supabase.from("user_action_stats").upsert(
      {
        user_id: uid,
        action_key: key,
        module: def?.module,
        label: def?.label,
        icon: def?.iconName,
        href: def?.href,
        ...patch,
      },
      { onConflict: "user_id,action_key" },
    );
    if (error) throw error;
  };

  const pin = useMutation({
    mutationFn: (key: string) => upsertRow(key, { pinned: true, hidden: false }),
    onSuccess: invalidate,
  });
  const unpin = useMutation({
    mutationFn: (key: string) => upsertRow(key, { pinned: false }),
    onSuccess: invalidate,
  });
  const hide = useMutation({
    mutationFn: (key: string) => upsertRow(key, { hidden: true, pinned: false }),
    onSuccess: invalidate,
  });
  const unhide = useMutation({
    mutationFn: (key: string) => upsertRow(key, { hidden: false }),
    onSuccess: invalidate,
  });
  const reorder = useMutation({
    mutationFn: async (orderedKeys: string[]) => {
      const { data: userRes } = await getCurrentUser();
      const uid = userRes.user?.id;
      if (!uid) throw new Error("Non authentifié");
      const rows = orderedKeys.map((key, idx) => {
        const def = findShortcut(key);
        return {
          user_id: uid,
          action_key: key,
          module: def?.module,
          label: def?.label,
          icon: def?.iconName,
          href: def?.href,
          pinned: true,
          sort_order: idx,
        };
      });
      const { error } = await supabase
        .from("user_action_stats")
        .upsert(rows, { onConflict: "user_id,action_key" });
      if (error) throw error;
    },
    onSuccess: invalidate,
  });

  return { pin, unpin, hide, unhide, reorder, catalog: SHORTCUTS_CATALOG };
}
