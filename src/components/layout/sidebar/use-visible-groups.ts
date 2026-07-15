import { usePermissions } from "@/hooks/use-permissions";
import { filterNavGroupsByPermissions } from "@/lib/rbac-menu-diagnostics";
import { groups, type Group } from "./nav-data";

/**
 * Menu 100 % piloté par la matrice RBAC.
 *
 * Règle unique : un item n'apparaît que si l'utilisateur possède la
 * permission déclarée dans `ROUTE_TO_PERMISSION`.
 *  - `null` (route libre pour tout authentifié) → visible.
 *  - `string` (permission requise) → visible si `has(perm)`.
 *  - `undefined` (route non mappée) → caché (aligné sur `RouteGuard` strict).
 *
 * Aucun rôle codé en dur, aucune exception par email ou libellé de groupe.
 */
export function useVisibleGroups(): Group[] {
  const { permissions, isSuperAdmin, isLoading } = usePermissions();

  if (isLoading) return [];
  if (isSuperAdmin) return groups;

  // Les groupes marqués `superAdminOnly` (ex. Administration) ne sont
  // jamais visibles pour un utilisateur non super-admin, quelles que
  // soient les permissions accordées dans la matrice RBAC.
  const accessible = groups.filter((g) => !g.superAdminOnly);
  return filterNavGroupsByPermissions(permissions, accessible);
}
