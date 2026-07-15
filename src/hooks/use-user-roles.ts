import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/use-auth";

export type AppRole =
  | "super_admin"
  | "directeur_general"
  | "comptable"
  | "directeur_commercial"
  | "gestionnaire_stock"
  | "responsable_magasinier"
  | "secretariat"
  | "assistante"
  | "service_logistique";

export function useUserRoles() {
  const { user, isLoading: authLoading } = useAuth();
  const [roles, setRoles] = useState<AppRole[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    if (authLoading) return;
    if (!user) {
      setRoles([]);
      setIsLoading(false);
      return;
    }
    (async () => {
      // P2 : unification super_admin — on considère l'utilisateur comme
      // super_admin s'il possède le rôle historique `user_roles.super_admin`
      // OU un rôle RBAC v2 dont le code est `super_admin`.
      const [legacy, rbac] = await Promise.all([
        supabase.from("user_roles").select("role").eq("user_id", user.id),
        supabase
          .from("rbac_user_roles")
          .select("rbac_roles!inner(code, actif)")
          .eq("user_id", user.id),
      ]);
      if (cancelled) return;
      const legacyRoles = (legacy.data ?? []).map((r) => r.role as AppRole);
      const hasRbacSuperAdmin = (rbac.data ?? []).some(
        (r) =>
          (r as { rbac_roles?: { code?: string; actif?: boolean } }).rbac_roles?.code ===
            "super_admin" &&
          (r as { rbac_roles?: { code?: string; actif?: boolean } }).rbac_roles?.actif !== false,
      );
      const merged = hasRbacSuperAdmin
        ? Array.from(new Set([...legacyRoles, "super_admin" as AppRole]))
        : legacyRoles;
      setRoles(merged);
      setIsLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [user, authLoading]);

  const hasRole = (r: AppRole) => roles.includes(r);
  const hasAny = (rs: AppRole[]) => rs.some((r) => roles.includes(r));
  const isSuperAdmin = roles.includes("super_admin");

  return { roles, hasRole, hasAny, isSuperAdmin, isLoading };
}
