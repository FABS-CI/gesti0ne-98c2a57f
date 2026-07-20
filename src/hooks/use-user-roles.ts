import { useQuery, useQueryClient } from "@tanstack/react-query";
import type { QueryClient } from "@tanstack/react-query";
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

type UserRolesRealtimeSubscription = {
  userId: string;
  channel: ReturnType<typeof supabase.channel>;
  queryClients: Set<QueryClient>;
  subscribers: number;
};

let activeUserRolesSubscription: UserRolesRealtimeSubscription | null = null;

function makeUserRolesChannelName(userId: string) {
  const suffix = globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2, 10);
  return `user-roles-${userId}-${suffix}`;
}

function registerUserRolesRealtime(userId: string, queryClient: QueryClient) {
  if (activeUserRolesSubscription?.userId === userId) {
    const subscription = activeUserRolesSubscription;
    subscription.subscribers += 1;
    subscription.queryClients.add(queryClient);

    return () => {
      subscription.queryClients.delete(queryClient);
      subscription.subscribers -= 1;
      if (subscription.subscribers <= 0) {
        void supabase.removeChannel(subscription.channel);
        if (activeUserRolesSubscription === subscription) activeUserRolesSubscription = null;
      }
    };
  }

  if (activeUserRolesSubscription) {
    void supabase.removeChannel(activeUserRolesSubscription.channel);
    activeUserRolesSubscription = null;
  }

  const queryClients = new Set<QueryClient>([queryClient]);
  const invalidateRoles = () => {
    queryClients.forEach((client) =>
      client.invalidateQueries({ queryKey: ["user-roles", userId] }),
    );
  };
  const channel = supabase
    .channel(makeUserRolesChannelName(userId))
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "user_roles", filter: `user_id=eq.${userId}` },
      invalidateRoles,
    )
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "rbac_user_roles", filter: `user_id=eq.${userId}` },
      invalidateRoles,
    )
    .subscribe();

  const subscription: UserRolesRealtimeSubscription = {
    userId,
    channel,
    queryClients,
    subscribers: 1,
  };
  activeUserRolesSubscription = subscription;

  return () => {
    subscription.queryClients.delete(queryClient);
    subscription.subscribers -= 1;
    if (subscription.subscribers <= 0) {
      void supabase.removeChannel(subscription.channel);
      if (activeUserRolesSubscription === subscription) activeUserRolesSubscription = null;
    }
  };
}

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
    return registerUserRolesRealtime(userId, qc);
  }, [userId, qc]);

  const roles = data ?? [];
  const hasRole = (r: AppRole) => roles.includes(r);
  const hasAny = (rs: AppRole[]) => rs.some((r) => roles.includes(r));
  const isSuperAdmin = roles.includes("super_admin");

  return { roles, hasRole, hasAny, isSuperAdmin, isLoading: authLoading || (!!userId && rolesLoading) };
}
