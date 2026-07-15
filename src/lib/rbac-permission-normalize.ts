/**
 * Normalise une liste de permissions RBAC pour l'affichage et les gardes UI.
 *
 * Règle métier : dès qu'une action est accordée sur un sous-module
 * (`sous_module.action`), la consultation du même sous-module
 * (`sous_module.voir`) est considérée comme accordée aussi.
 */
export function expandRbacViewPermissions(permissions: Iterable<string>): Set<string> {
  const expanded = new Set<string>();

  for (const permission of permissions) {
    expanded.add(permission);

    const separatorIndex = permission.indexOf(".");
    if (separatorIndex <= 0) continue;

    const sousModule = permission.slice(0, separatorIndex);
    const action = permission.slice(separatorIndex + 1);
    if (!sousModule || action === "voir") continue;

    expanded.add(`${sousModule}.voir`);
  }

  return expanded;
}