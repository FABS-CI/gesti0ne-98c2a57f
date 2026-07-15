import { readFileSync } from "node:fs";

const routePermissionSource = readFileSync("src/lib/route-permissions.ts", "utf8");
const catalogSource = readFileSync("src/lib/rbac-catalog.ts", "utf8");

const intentionallyUnroutedViewPermissions = new Set([
  // Catalogue prêt, mais aucune surface route n'est livrée pour ces sous-modules.
  "avoirs.voir",
  "bulletins.voir",
  "dashboard_personnel.voir",
  "integrations.voir",
  "livraisons.voir",
  "mon_dashboard.voir",
  "notifications.voir",
  "profil.voir",
  "prospects.voir",
  "tarifs.voir",
  "tresorerie.voir",
]);

const routeMapMatch = routePermissionSource.match(
  /export const ROUTE_TO_PERMISSION[\s\S]*?=\s*\{([\s\S]*?)\n\};/,
);

if (!routeMapMatch) {
  console.error("RBAC coverage: ROUTE_TO_PERMISSION introuvable.");
  process.exit(1);
}

const routePermissions = new Set(
  Array.from(routeMapMatch[1].matchAll(/"([a-z0-9_]+\.[a-z0-9_]+)"/g), (match) => match[1]),
);

const actionRowsMatch = catalogSource.match(/export const ACTIONS[\s\S]*?= \[([\s\S]*?)\n\];/);
const moduleRowsMatch = catalogSource.match(/export const MODULE_GROUPS[\s\S]*?= \[([\s\S]*?)\n\];/);

if (!moduleRowsMatch || !actionRowsMatch) {
  console.error("RBAC coverage: seed catalogue permissions introuvable.");
  process.exit(1);
}

const sousModules = Array.from(
  moduleRowsMatch[1].matchAll(/\{\s*code:\s*"([a-z0-9_]+)",\s*libelle:/g),
  (match) => match[1],
);
const actions = Array.from(
  actionRowsMatch[1].matchAll(/\{\s*code:\s*"([a-z0-9_]+)",\s*libelle:/g),
  (match) => match[1],
);
const catalogPermissions = new Set(
  sousModules.flatMap((sousModule) => actions.map((action) => `${sousModule}.${action}`)),
);

for (const match of catalogSource.matchAll(/\{\s*code:\s*"([a-z0-9_]+\.[a-z0-9_]+)"[,\s]/g)) {
  catalogPermissions.add(match[1]);
}

const unknownRoutePermissions = Array.from(routePermissions)
  .filter((permission) => !catalogPermissions.has(permission))
  .sort();

const catalogViewPermissions = Array.from(catalogPermissions)
  .filter((permission) => permission.endsWith(".voir"))
  .filter((permission) => !intentionallyUnroutedViewPermissions.has(permission))
  .filter((permission) => !routePermissions.has(permission))
  .sort();

if (unknownRoutePermissions.length > 0 || catalogViewPermissions.length > 0) {
  if (unknownRoutePermissions.length > 0) {
    console.error("Permissions route absentes du catalogue:");
    for (const permission of unknownRoutePermissions) console.error(`- ${permission}`);
  }
  if (catalogViewPermissions.length > 0) {
    console.error("Permissions catalogue .voir non référencées par une route:");
    for (const permission of catalogViewPermissions) console.error(`- ${permission}`);
  }
  process.exit(1);
}

console.log(
  `RBAC coverage OK: ${routePermissions.size} permissions route vérifiées, ${catalogViewPermissions.length} .voir orphelines.`,
);