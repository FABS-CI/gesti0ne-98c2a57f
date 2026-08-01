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
      { event: "*", schema: "public", table: "rbac2_user_roles", filter: `user_id=eq.${userId}` },
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
      // Source de vérité : RBAC v3 (`rbac3_user_roles`), alignée sur les
      // policies RLS. Repli sur `rbac2_user_roles` pour les comptes non migrés.
      const v3 = await supabase
        .from("rbac3_user_roles")
        .select("role_code, rbac3_roles!inner(statut)")
        .eq("user_id", userId!);
      const v3Roles = (v3.data ?? [])
        .filter((r) => {
          const statut = (r as { rbac3_roles?: { statut?: string } }).rbac3_roles?.statut;
          return statut !== "archive" && statut !== "inactif";
        })
        .map((r) => (r as { role_code: string }).role_code as AppRole);
      if (v3Roles.length > 0) return Array.from(new Set(v3Roles));

      const v2 = await supabase
        .from("rbac2_user_roles")
        .select("role_code, rbac2_roles!inner(statut)")
        .eq("user_id", userId!);
      const v2Roles = (v2.data ?? [])
        .filter(
          (r) =>
            (r as { rbac2_roles?: { statut?: string } }).rbac2_roles?.statut !== "archive" &&
            (r as { rbac2_roles?: { statut?: string } }).rbac2_roles?.statut !== "inactif",
        )
        .map((r) => (r as { role_code: string }).role_code as AppRole);
      return Array.from(new Set(v2Roles));
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
