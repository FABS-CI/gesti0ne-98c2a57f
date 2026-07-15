/**
 * Tests d'intégration — filtrage RBAC des raccourcis intelligents et
 * modules favoris. Vérifie que `useSmartShortcuts` et `useFavoriteModules`
 * n'exposent que les entrées autorisées par les permissions de l'utilisateur.
 *
 * Exécution : `bunx vitest run src/hooks/__tests__/use-smart-shortcuts.test.tsx`
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import React from "react";

// --- mocks ---------------------------------------------------------------
type Row = {
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
};

let statsRows: Row[] = [];
let permsState = {
  isSuperAdmin: false,
  isLoading: false,
  has: (_k: string) => false,
};

vi.mock("@/integrations/supabase/client", () => ({
  supabase: {
    from: () => ({
      select: () => Promise.resolve({ data: statsRows, error: null }),
    }),
    auth: {
      getSession: () => Promise.resolve({ data: { session: null }, error: null }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
    },
  },
}));

vi.mock("@/hooks/use-permissions", () => ({
  usePermissions: () => permsState,
}));

import { useSmartShortcuts, useFavoriteModules } from "../use-smart-shortcuts";

function makeRow(partial: Partial<Row> & { action_key: string; module?: string | null }): Row {
  return {
    id: partial.action_key,
    action_key: partial.action_key,
    module: partial.module ?? null,
    label: null,
    icon: null,
    href: null,
    usage_count: partial.usage_count ?? 10,
    last_used_at: partial.last_used_at ?? new Date().toISOString(),
    pinned: partial.pinned ?? false,
    hidden: partial.hidden ?? false,
    sort_order: partial.sort_order ?? 0,
  };
}

function wrapper() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: ReactNode }) =>
    React.createElement(QueryClientProvider, { client: qc }, children);
}

beforeEach(() => {
  statsRows = [];
  permsState = { isSuperAdmin: false, isLoading: false, has: () => false };
});

describe("useSmartShortcuts – filtrage RBAC", () => {
  it("masque les raccourcis dont la permission action n'est pas accordée", async () => {
    statsRows = [
      makeRow({ action_key: "commandes.create", module: "commercial", usage_count: 50 }),
      makeRow({ action_key: "factures.create", module: "finance", usage_count: 40 }),
    ];
    permsState = {
      isSuperAdmin: false,
      isLoading: false,
      // Autorise commandes.creer + route commandes, refuse factures.*
      has: (k) => k === "commandes.creer" || k === "commandes.voir",
    };

    const { result } = renderHook(() => useSmartShortcuts(6), { wrapper: wrapper() });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    const keys = result.current.shortcuts.map((s) => s.def.key);
    expect(keys).toContain("commandes.create");
    expect(keys).not.toContain("factures.create");
  });

  it("masque un raccourci quand la permission de la route module manque (defense in depth)", async () => {
    statsRows = [makeRow({ action_key: "clients.create", module: "crm", usage_count: 25 })];
    permsState = {
      isSuperAdmin: false,
      isLoading: false,
      // Action autorisée mais /clients (clients.voir) refusée => masqué
      has: (k) => k === "clients.creer",
    };

    const { result } = renderHook(() => useSmartShortcuts(6), { wrapper: wrapper() });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    const keys = result.current.shortcuts.map((s) => s.def.key);
    expect(keys).not.toContain("clients.create");
  });

  it("un super_admin voit tous les raccourcis, y compris les défauts sans stats", async () => {
    statsRows = [];
    permsState = { isSuperAdmin: true, isLoading: false, has: () => false };

    const { result } = renderHook(() => useSmartShortcuts(6), { wrapper: wrapper() });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    // Le fallback des défauts remplit la liste pour super_admin
    expect(result.current.shortcuts.length).toBeGreaterThan(0);
    const keys = result.current.shortcuts.map((s) => s.def.key);
    expect(keys).toEqual(expect.arrayContaining(["commandes.create"]));
  });

  it("un utilisateur sans aucune permission n'a aucun raccourci (même fallback vide)", async () => {
    statsRows = [];
    permsState = { isSuperAdmin: false, isLoading: false, has: () => false };

    const { result } = renderHook(() => useSmartShortcuts(6), { wrapper: wrapper() });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.shortcuts).toHaveLength(0);
  });

  it("respecte l'ordre : épinglés autorisés d'abord, puis suggestions", async () => {
    statsRows = [
      makeRow({
        action_key: "paiements.create",
        module: "finance",
        usage_count: 5,
        pinned: true,
        sort_order: 0,
      }),
      makeRow({
        action_key: "commandes.create",
        module: "commercial",
        usage_count: 999,
      }),
    ];
    permsState = {
      isSuperAdmin: false,
      isLoading: false,
      has: (k) =>
        ["paiements.creer", "paiements.voir", "commandes.creer", "commandes.voir"].includes(k),
    };

    const { result } = renderHook(() => useSmartShortcuts(6), { wrapper: wrapper() });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    const keys = result.current.shortcuts.map((s) => s.def.key);
    expect(keys[0]).toBe("paiements.create");
    expect(keys).toContain("commandes.create");
  });

  it("un raccourci épinglé mais dont la permission a été révoquée n'apparaît plus", async () => {
    statsRows = [
      makeRow({
        action_key: "factures.create",
        module: "finance",
        pinned: true,
        usage_count: 42,
      }),
    ];
    permsState = { isSuperAdmin: false, isLoading: false, has: () => false };

    const { result } = renderHook(() => useSmartShortcuts(6), { wrapper: wrapper() });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    const keys = result.current.shortcuts.map((s) => s.def.key);
    expect(keys).not.toContain("factures.create");
  });
});

describe("useFavoriteModules – filtrage RBAC", () => {
  it("exclut les modules dont la route n'est pas autorisée", async () => {
    statsRows = [
      makeRow({ action_key: "commandes.create", module: "commercial", usage_count: 30 }),
      makeRow({ action_key: "factures.create", module: "finance", usage_count: 100 }),
    ];
    permsState = {
      isSuperAdmin: false,
      isLoading: false,
      // /commandes autorisée, /comptabilite (module finance) non
      has: (k) => k === "commandes.voir",
    };

    const { result } = renderHook(() => useFavoriteModules(5), { wrapper: wrapper() });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    const mods = result.current.modules.map((m) => m.module);
    expect(mods).toContain("commercial");
    expect(mods).not.toContain("finance");
  });

  it("super_admin voit tous les modules ayant des stats", async () => {
    statsRows = [
      makeRow({ action_key: "commandes.create", module: "commercial", usage_count: 3 }),
      makeRow({ action_key: "factures.create", module: "finance", usage_count: 7 }),
    ];
    permsState = { isSuperAdmin: true, isLoading: false, has: () => false };

    const { result } = renderHook(() => useFavoriteModules(5), { wrapper: wrapper() });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    const mods = result.current.modules.map((m) => m.module);
    expect(mods).toEqual(expect.arrayContaining(["commercial", "finance"]));
  });

  it("utilisateur sans aucune permission ne voit aucun module favori", async () => {
    statsRows = [
      makeRow({ action_key: "commandes.create", module: "commercial", usage_count: 30 }),
    ];
    permsState = { isSuperAdmin: false, isLoading: false, has: () => false };

    const { result } = renderHook(() => useFavoriteModules(5), { wrapper: wrapper() });
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.modules).toHaveLength(0);
  });
});
