import { useQuery, useQueryClient } from "@tanstack/react-query";
import type { QueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/use-auth";
import { useUserRoles } from "@/hooks/use-user-roles";
import { expandRbacViewPermissions } from "@/lib/rbac-permission-normalize";

type RbacRealtimeSubscription = {
  userId: string;
  channel: ReturnType<typeof supabase.channel>;
  queryClients: Set<QueryClient>;
  subscribers: number;
};

let activeRbacRealtimeSubscription: RbacRealtimeSubscription | null = null;

function makeRbacChannelName(userId: string) {
  const suffix = globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2, 10);
  return `rbac-perms-${userId}-${suffix}`;
}

function registerRbacRealtime(userId: string, queryClient: QueryClient) {
  if (activeRbacRealtimeSubscription?.userId === userId) {
    activeRbacRealtimeSubscription.subscribers += 1;
    activeRbacRealtimeSubscription.queryClients.add(queryClient);
    const subscription = activeRbacRealtimeSubscription;

    return () => {
      subscription.queryClients.delete(queryClient);
      subscription.subscribers -= 1;
      if (subscription.subscribers <= 0) {
        supabase.removeChannel(subscription.channel);
        if (activeRbacRealtimeSubscription === subscription) activeRbacRealtimeSubscription = null;
      }
    };
  }

  if (activeRbacRealtimeSubscription) {
    supabase.removeChannel(activeRbacRealtimeSubscription.channel);
    activeRbacRealtimeSubscription = null;
  }

  const queryClients = new Set<QueryClient>([queryClient]);
  const invalidatePermissions = () => {
    queryClients.forEach((client) => client.invalidateQueries({ queryKey: ["rbac", "permissions"] }));
  };

  const channel = supabase
    .channel(makeRbacChannelName(userId))
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "rbac_role_permissions" },
      invalidatePermissions,
    )
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "rbac_user_roles", filter: `user_id=eq.${userId}` },
      invalidatePermissions,
    )
    .subscribe();

  const subscription: RbacRealtimeSubscription = {
    userId,
    channel,
    queryClients,
    subscribers: 1,
  };
  activeRbacRealtimeSubscription = subscription;

  return () => {
    subscription.queryClients.delete(queryClient);
    subscription.subscribers -= 1;
    if (subscription.subscribers <= 0) {
      supabase.removeChannel(subscription.channel);
      if (activeRbacRealtimeSubscription === subscription) activeRbacRealtimeSubscription = null;
    }
  };
}

/**
 * Hook central RBAC v2.
 * - Charge la liste plate `permission_code[]` via RPC `list_user_permissions`.
 * - Cache TanStack Query court, invalidé automatiquement lorsque
 *   `rbac_role_permissions` ou `rbac_user_roles` changent (realtime).
 * - Super admin (rôle historique `user_roles`) => bypass automatique.
 */
export function usePermissions() {
  const { user, isLoading: authLoading } = useAuth();
  const { isSuperAdmin, isLoading: rolesLoading } = useUserRoles();
  const qc = useQueryClient();
  const userId = user?.id ?? null;

  const query = useQuery({
    queryKey: ["rbac", "permissions", userId],
    enabled: !!userId && !authLoading,
    // 10 s : fallback court si le realtime rate un événement (onglet inactif,
    // mobile, reconnexion réseau), sans requêter en boucle la RPC.
    staleTime: 10_000,
    refetchOnWindowFocus: true,
    refetchOnReconnect: true,
    queryFn: async () => {
      if (!userId) return new Set<string>();
      const { data, error } = await supabase.rpc("list_user_permissions", {
        _user_id: userId,
      });
      if (error) throw error;
      return expandRbacViewPermissions((data ?? []).map((r) => r.permission_code));
    },
  });

  // Realtime : un seul abonnement RBAC par utilisateur, partagé par tous les composants.
  // Les callbacks sont toujours déclarés avant subscribe(), puis les autres hooks réutilisent
  // l'abonnement existant sans y rattacher de nouveaux listeners.
  useEffect(() => {
    if (!userId) return;
    return registerRbacRealtime(userId, qc);
  }, [userId, qc]);

  // Fallback explicite : au retour d'un onglet inactif, on force la
  // revalidation même si le WebSocket n'a pas livré l'événement RBAC.
  useEffect(() => {
    if (!userId) return;

    const handleVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        qc.invalidateQueries({ queryKey: ["rbac", "permissions", userId] });
      }
    };

    document.addEventListener("visibilitychange", handleVisibilityChange);
    return () => document.removeEventListener("visibilitychange", handleVisibilityChange);
  }, [userId, qc]);

  // Fonction exposée : force le rafraîchissement immédiat (bouton "Recharger mes droits").
  const refresh = () => qc.refetchQueries({ queryKey: ["rbac", "permissions", userId] });

  const permissions = query.data ?? new Set<string>();

  const has = (key: string) => isSuperAdmin || permissions.has(key);
  const hasAny = (keys: string[]) => isSuperAdmin || keys.some((k) => permissions.has(k));
  const hasAll = (keys: string[]) => isSuperAdmin || keys.every((k) => permissions.has(k));

  return {
    permissions,
    has,
    hasAny,
    hasAll,
    isSuperAdmin,
    isLoading: authLoading || rolesLoading || query.isLoading,
    refresh,
  };
}
