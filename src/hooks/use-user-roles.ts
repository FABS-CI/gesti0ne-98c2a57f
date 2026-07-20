import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
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

/**
 * P0 perf : mise en cache via React Query (staleTime long) pour éviter les
 * ~23k lectures/semaine de `user_roles`. Invalidation via Realtime sur
 * `user_roles` et `rbac_user_roles` pour l'utilisateur courant.
 */
export function useUserRoles() {
  const { user, isLoading: authLoading } = useAuth();
  const qc = useQueryClient();
  const userId = user?.id;

  const { data, isLoading: rolesLoading } = useQuery({
    queryKey: ["user-roles", userId],
    enabled: !!userId && !authLoading,
    staleTime: 10 * 60_000, // 10 min
    gcTime: 30 * 60_000,
    refetchOnWindowFocus: false,
    refetchOnMount: false,
    queryFn: async (): Promise<AppRole[]> => {
      const [legacy, rbac] = await Promise.all([
        supabase.from("user_roles").select("role").eq("user_id", userId!),
        supabase
          .from("rbac_user_roles")
          .select("rbac_roles!inner(code, actif)")
          .eq("user_id", userId!),
      ]);
      const legacyRoles = (legacy.data ?? []).map((r) => r.role as AppRole);
      const hasRbacSuperAdmin = (rbac.data ?? []).some(
        (r) =>
          (r as { rbac_roles?: { code?: string; actif?: boolean } }).rbac_roles?.code ===
            "super_admin" &&
          (r as { rbac_roles?: { code?: string; actif?: boolean } }).rbac_roles?.actif !== false,
      );
      return hasRbacSuperAdmin
        ? Array.from(new Set([...legacyRoles, "super_admin" as AppRole]))
        : legacyRoles;
    },
  });

  // Invalidation temps réel : si les rôles du user changent, on rafraîchit.
  useEffect(() => {
    if (!userId) return;
    const channel = supabase
      .channel(`user-roles-${userId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "user_roles", filter: `user_id=eq.${userId}` },
        () => qc.invalidateQueries({ queryKey: ["user-roles", userId] }),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "rbac_user_roles", filter: `user_id=eq.${userId}` },
        () => qc.invalidateQueries({ queryKey: ["user-roles", userId] }),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId, qc]);

  const roles = data ?? [];
  const hasRole = (r: AppRole) => roles.includes(r);
  const hasAny = (rs: AppRole[]) => rs.some((r) => roles.includes(r));
  const isSuperAdmin = roles.includes("super_admin");

  return { roles, hasRole, hasAny, isSuperAdmin, isLoading: authLoading || (!!userId && rolesLoading) };
}
