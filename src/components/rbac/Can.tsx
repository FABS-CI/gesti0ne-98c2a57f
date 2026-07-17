import type { ReactNode } from "react";
import { useEffect, useRef } from "react";
import { usePermissions } from "@/hooks/use-permissions";
import { RBAC_PERMISSION_CODES } from "@/lib/rbac-permission-codes";

type CanProps = {
  permission?: string;
  anyOf?: string[];
  allOf?: string[];
  fallback?: ReactNode;
  children: ReactNode;
};

// Set global de permissions déjà signalées comme inconnues, pour éviter
// de spammer la console à chaque re-render en développement.
const warnedUnknownPermissions = new Set<string>();

function warnIfUnknown(codes: (string | undefined)[]) {
  if (!import.meta.env.DEV) return;
  for (const code of codes) {
    if (!code) continue;
    if (RBAC_PERMISSION_CODES.has(code)) continue;
    if (warnedUnknownPermissions.has(code)) continue;
    warnedUnknownPermissions.add(code);
    // eslint-disable-next-line no-console
    console.warn(
      `[RBAC] <Can> référence une permission inconnue du catalogue: "${code}". ` +
        `Ajoute-la à rbac_permissions ou corrige l'appelant.`,
    );
  }
}

/**
 * Gate déclaratif RBAC v2.
 *
 * <Can permission="commandes.creer"><Button ... /></Can>
 * <Can anyOf={["factures.valider","factures.annuler"]}>…</Can>
 *
 * En développement, journalise un warning si une permission référencée
 * n'existe pas dans le catalogue `rbac_permissions` (fail-closed silencieux
 * en production, mais visible pendant le dev).
 */
export function Can({ permission, anyOf, allOf, fallback = null, children }: CanProps) {
  const { has, hasAny, hasAll, isLoading } = usePermissions();

  // Warning une seule fois par permission inconnue.
  const checkedRef = useRef(false);
  useEffect(() => {
    if (checkedRef.current) return;
    checkedRef.current = true;
    warnIfUnknown([permission, ...(anyOf ?? []), ...(allOf ?? [])]);
  }, [permission, anyOf, allOf]);

  if (isLoading) return null;

  const ok =
    (permission ? has(permission) : true) &&
    (anyOf && anyOf.length > 0 ? hasAny(anyOf) : true) &&
    (allOf && allOf.length > 0 ? hasAll(allOf) : true) &&
    (permission || anyOf?.length || allOf?.length ? true : false);

  if (!ok) return <>{fallback}</>;
  return <>{children}</>;
}
