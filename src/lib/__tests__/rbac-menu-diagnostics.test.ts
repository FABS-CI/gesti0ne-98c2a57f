import { describe, expect, it } from "vitest";

import { groups } from "@/components/layout/sidebar/nav-data";
import {
  diagnoseExpectedMenuGroups,
  EXPECTED_RBAC_MENU_GROUPS,
  filterNavGroupsByPermissions,
} from "@/lib/rbac-menu-diagnostics";
import { getRoutePermission } from "@/lib/route-permissions";

function requiredPermissionsFor(label: keyof typeof EXPECTED_RBAC_MENU_GROUPS) {
  return EXPECTED_RBAC_MENU_GROUPS[label].flatMap((item) => {
    const requirement = getRoutePermission(item.url);
    if (!requirement) return [];
    return Array.isArray(requirement) ? requirement : [requirement];
  });
}

describe("RBAC menu diagnostics", () => {
  it("validates the exact Gestion commerciale menu when all expected rights are granted", () => {
    const permissions = requiredPermissionsFor("Gestion commerciale");
    const visibleGroups = filterNavGroupsByPermissions(permissions, groups);
    const [commercial] = diagnoseExpectedMenuGroups(permissions, visibleGroups);

    expect(commercial.label).toBe("Gestion commerciale");
    expect(commercial.expectedCount).toBe(8);
    expect(commercial.permissionsAccordees).toBe(8);
    expect(commercial.sousModulesAffiches).toBe(8);
    expect(commercial.missing).toEqual([]);
    expect(commercial.unexpected).toEqual([]);
    expect(commercial.isOk).toBe(true);
  });

  it("validates the exact Stocks & Logistique menu when all expected rights are granted", () => {
    const permissions = requiredPermissionsFor("Stocks & Logistique");
    const visibleGroups = filterNavGroupsByPermissions(permissions, groups);
    const diagnostics = diagnoseExpectedMenuGroups(permissions, visibleGroups);
    const stock = diagnostics.find((diagnostic) => diagnostic.label === "Stocks & Logistique");

    expect(stock?.expectedCount).toBe(19);
    expect(stock?.permissionsAccordees).toBe(19);
    expect(stock?.sousModulesAffiches).toBe(19);
    expect(stock?.missing).toEqual([]);
    expect(stock?.unexpected).toEqual([]);
    expect(stock?.isOk).toBe(true);
  });

  it("flags a granted permission whose sidebar item is missing", () => {
    const permissions = requiredPermissionsFor("Gestion commerciale");
    const navWithoutFactures = groups.map((group) =>
      group.label === "Gestion commerciale"
        ? { ...group, items: group.items.filter((item) => item.url !== "/factures") }
        : group,
    );

    const visibleGroups = filterNavGroupsByPermissions(permissions, navWithoutFactures);
    const [commercial] = diagnoseExpectedMenuGroups(permissions, visibleGroups);

    expect(commercial.isOk).toBe(false);
    expect(commercial.missing.map((item) => item.title)).toEqual(["Factures"]);
  });

  it("hides a submodule immediately when its view permission is removed", () => {
    const permissions = requiredPermissionsFor("Stocks & Logistique").filter(
      (permission) => permission !== "livreurs.voir",
    );
    const visibleGroups = filterNavGroupsByPermissions(permissions, groups);
    const diagnostics = diagnoseExpectedMenuGroups(permissions, visibleGroups);
    const stock = diagnostics.find((diagnostic) => diagnostic.label === "Stocks & Logistique");

    expect(stock?.permissionsAccordees).toBe(18);
    expect(stock?.sousModulesAffiches).toBe(18);
    expect(stock?.missing).toEqual([]);
    expect(stock?.unexpected).toEqual([]);
  });

  it("shows commercial menu entries when an action permission implies .voir", () => {
    const visibleGroups = filterNavGroupsByPermissions(
      ["proformas.creer", "retours.modifier"],
      groups,
    );
    const commercial = visibleGroups.find((group) => group.label === "Gestion commerciale");

    expect(commercial?.items.map((item) => item.title)).toEqual(["Proformas", "Retours"]);
  });

  it("shows logistics menu entries when action permissions imply .voir", () => {
    const visibleGroups = filterNavGroupsByPermissions(
      ["fournisseurs.modifier", "transferts.creer", "flotte.modifier", "tournees.cloturer", "rapports_logistique.exporter_pdf"],
      groups,
    );
    const stock = visibleGroups.find((group) => group.label === "Stocks & Logistique");

    expect(stock?.items.map((item) => item.title)).toEqual([
      "Fournisseurs",
      "Transferts",
      "Flotte",
      "Tournées",
      "Rapports logistique",
    ]);
  });
});
