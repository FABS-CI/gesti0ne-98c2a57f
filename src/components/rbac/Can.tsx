import type { ReactNode } from "react";
import { usePermissions } from "@/hooks/use-permissions";

type CanProps = {
  permission?: string;
  anyOf?: string[];
  allOf?: string[];
  fallback?: ReactNode;
  children: ReactNode;
};

/**
 * Gate déclaratif RBAC v2.
 *
 * <Can permission="commandes.creer"><Button ... /></Can>
 * <Can anyOf={["factures.valider","factures.annuler"]}>…</Can>
 */
export function Can({ permission, anyOf, allOf, fallback = null, children }: CanProps) {
  const { has, hasAny, hasAll, isLoading } = usePermissions();
  if (isLoading) return null;

  const ok =
    (permission ? has(permission) : true) &&
    (anyOf && anyOf.length > 0 ? hasAny(anyOf) : true) &&
    (allOf && allOf.length > 0 ? hasAll(allOf) : true) &&
    (permission || anyOf?.length || allOf?.length ? true : false);

  if (!ok) return <>{fallback}</>;
  return <>{children}</>;
}
