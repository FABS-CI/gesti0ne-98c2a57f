import type { RoutePermissionRequirement } from "@/lib/route-permissions";
import { expandRbacViewPermissions } from "@/lib/rbac-permission-normalize";
import { getRoutePermission } from "@/lib/route-permissions";

export type ExpectedMenuItem = {
  title: string;
  url: string;
};

export type NavGroupLike = {
  label: string;
  items: Array<{ title: string; url: string }>;
};

export type RbacMenuDiagnostic = {
  label: string;
  expectedCount: number;
  permissionsAccordees: number;
  sousModulesAffiches: number;
  missing: ExpectedMenuItem[];
  unexpected: ExpectedMenuItem[];
  isOk: boolean;
};

export const EXPECTED_RBAC_MENU_GROUPS: Record<string, ExpectedMenuItem[]> = {
  "Gestion commerciale": [
    { title: "Clients", url: "/clients" },
    { title: "CRM & Analyses", url: "/clients/dashboard" },
    { title: "Commandes", url: "/commandes" },
    { title: "Proformas", url: "/proformas" },
    { title: "Factures", url: "/factures" },
    { title: "Paiements", url: "/paiements" },
    { title: "Retours", url: "/retours" },
    { title: "Spécimens", url: "/specimens" },
  ],
  "Stocks & Logistique": [
    { title: "Produits", url: "/produits" },
    { title: "Dépôts", url: "/depots" },
    { title: "Approvisionnements", url: "/achats" },
    { title: "Mouvements de Stock", url: "/stock" },
    { title: "Colisage", url: "/colisage" },
    { title: "Préparateurs / Responsables colisage", url: "/colisage/responsables" },
    { title: "Suivi des livraisons", url: "/livraison-suivi" },
    { title: "Bons de livraison", url: "/bons-livraison" },
    { title: "Inventaires", url: "/inventaires" },
    { title: "Incidents de Stock", url: "/incidents" },
    { title: "Alertes de Stock", url: "/alertes-stock" },
    { title: "Audit stock", url: "/stock/audit" },
    { title: "Fournisseurs", url: "/fournisseurs" },
    { title: "Transferts", url: "/transferts" },
    { title: "Flotte", url: "/fleet" },
    { title: "Tournées", url: "/tournees" },
    { title: "Livreurs", url: "/livreurs" },
    { title: "Dashboard logistique", url: "/dashboard-logistique" },
    { title: "Rapports logistique", url: "/rapports-logistique" },
  ],
};

function hasRequirement(
  permissions: ReadonlySet<string>,
  requirement: RoutePermissionRequirement | undefined,
) {
  if (requirement === null) return true;
  if (requirement === undefined) return false;
  if (Array.isArray(requirement)) return requirement.some((permission) => permissions.has(permission));
  return permissions.has(requirement);
}

export function filterNavGroupsByPermissions<TGroup extends NavGroupLike>(
  permissions: Iterable<string>,
  navGroups: TGroup[],
): TGroup[] {
  const permissionSet = expandRbacViewPermissions(permissions);

  return navGroups
    .map((group) => ({
      ...group,
      items: group.items.filter((item) => hasRequirement(permissionSet, getRoutePermission(item.url))),
    }))
    .filter((group) => group.items.length > 0);
}

export function diagnoseExpectedMenuGroups(
  permissions: Iterable<string>,
  navGroups: NavGroupLike[],
): RbacMenuDiagnostic[] {
  const permissionSet = expandRbacViewPermissions(permissions);

  return Object.entries(EXPECTED_RBAC_MENU_GROUPS).map(([label, expectedItems]) => {
    const navGroup = navGroups.find((group) => group.label === label);
    const navItemsByUrl = new Set((navGroup?.items ?? []).map((item) => item.url));

    const grantedItems = expectedItems.filter((item) =>
      hasRequirement(permissionSet, getRoutePermission(item.url)),
    );
    const displayedItems = expectedItems.filter(
      (item) => navItemsByUrl.has(item.url) && hasRequirement(permissionSet, getRoutePermission(item.url)),
    );
    const missing = expectedItems.filter(
      (item) =>
        hasRequirement(permissionSet, getRoutePermission(item.url)) && !navItemsByUrl.has(item.url),
    );
    const unexpected = expectedItems.filter(
      (item) =>
        navItemsByUrl.has(item.url) && !hasRequirement(permissionSet, getRoutePermission(item.url)),
    );

    return {
      label,
      expectedCount: expectedItems.length,
      permissionsAccordees: grantedItems.length,
      sousModulesAffiches: displayedItems.length,
      missing,
      unexpected,
      isOk: missing.length === 0 && unexpected.length === 0,
    };
  });
}
