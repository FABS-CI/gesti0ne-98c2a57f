/**
 * Surcouches métier au RBAC.
 *
 * Ce fichier ne remplace PAS le catalogue RBAC (voir `rbac_permissions` en base
 * et le hook `usePermissions`). Il n'expose que deux règles métier qui restent
 * codées côté frontend en attendant leur migration complète dans la matrice
 * RBAC :
 *   1. `isUserRestricted(email, url)` — interdiction par email pour un compte
 *      précis, appliquée en plus des rôles ; utile pour bloquer un salarié
 *      individuel sans modifier son rôle.
 *   2. `isReadOnly(module, roles)` — modules consultables sans mutation pour
 *      certains rôles (ex. la Direction Commerciale sur clients/commandes).
 *
 * Tout le reste (ancienne matrice `ROUTE_PERMISSIONS`, `PERMISSIONS`,
 * `canAccess`, `hasPermission(perm, roles)`, `canMutateSpecimen`, etc.) a été
 * supprimé le 2026-07-17 après audit RBAC : ces API faisaient doublon avec la
 * table `rbac_permissions` et pouvaient diverger silencieusement.
 * Utiliser `usePermissions().has("module.action")` à la place.
 */
import type { AppRole } from "@/hooks/use-user-roles";

/**
 * Restrictions par utilisateur (email) — surcouche RBAC.
 * Permet d'interdire l'accès à certaines routes (préfixes) pour un user
 * précis, indépendamment de ses rôles. Appliqué côté frontend (menus +
 * garde de route). Côté backend, des policies RLS restrictives bloquent
 * également l'accès aux données concernées.
 */
export const USER_RESTRICTIONS: Record<string, string[]> = {
  "yakeben@editionsfabsci.com": ["/incidents", "/alertes-stock", "/transferts"],
};

export function isUserRestricted(email: string | null | undefined, url: string): boolean {
  if (!email) return false;
  const list = USER_RESTRICTIONS[email.toLowerCase()];
  if (!list) return false;
  return list.some((prefix) => url === prefix || url.startsWith(prefix + "/"));
}

/**
 * Modules en lecture seule pour certains rôles.
 * Le directeur commercial consulte Clients, Commandes et Livraisons
 * sans pouvoir créer, modifier ou supprimer (matrice FABS-CI V10).
 *
 * NOTE : cette règle est appliquée en surcouche du RBAC. Le seed RBAC peut
 * accorder `.creer`/`.modifier` à `directeur_commercial`, mais le composant
 * qui appelle `isReadOnly` cache/désactive tout de même les actions d'écriture
 * sur les modules listés ci-dessous. Migrer cette règle dans la matrice RBAC
 * demanderait de retirer explicitement ces permissions au rôle — ce qui
 * changerait aussi d'autres écrans ; à trancher côté produit avant toute
 * bascule.
 */
const READ_ONLY_MATRIX: Partial<Record<AppRole, string[]>> = {
  directeur_commercial: ["clients", "commandes", "livraisons", "specimens"],
};

export function isReadOnly(module: string, roles: AppRole[]): boolean {
  if (roles.includes("super_admin")) return false;
  // Si l'utilisateur a au moins un rôle qui n'est PAS read-only sur ce module,
  // il peut écrire. Sinon, s'il possède un rôle read-only sur ce module, on
  // bloque les mutations côté UI.
  const writers = roles.filter((r) => !(READ_ONLY_MATRIX[r] ?? []).includes(module));
  if (writers.length > 0) return false;
  return roles.some((r) => (READ_ONLY_MATRIX[r] ?? []).includes(module));
}
