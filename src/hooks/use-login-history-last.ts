import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export type LoginInfo = {
  email: string;
  ip_address: string | null;
  user_agent: string | null;
  device: string | null;
  occurred_at: string;
};

/**
 * Récupère les dernières connexions (login_history) pour indexer par email
 * la dernière IP / user-agent / device connus. Utilisé par l'onglet
 * "Connectés" pour enrichir la ligne utilisateur (les événements d'audit
 * générés par des triggers ne portent pas l'IP).
 */
export function useLoginHistoryLast() {
  return useQuery({
    queryKey: ["login-history-last"],
    queryFn: async () => {
      const since = new Date();
      since.setDate(since.getDate() - 7);
      const { data, error } = await supabase
        .from("login_history")
        .select("email, ip_address, user_agent, device, occurred_at, status")
        .eq("status", "success")
        .gte("occurred_at", since.toISOString())
        .order("occurred_at", { ascending: false })
        .limit(500);
      if (error) throw error;
      const map = new Map<string, LoginInfo>();
      (data ?? []).forEach((r) => {
        const key = (r.email ?? "").toLowerCase();
        if (!key || map.has(key)) return; // premier = plus récent
        map.set(key, {
          email: r.email ?? "",
          ip_address: r.ip_address ?? null,
          user_agent: r.user_agent ?? null,
          device: r.device ?? null,
          occurred_at: r.occurred_at,
        });
      });
      return map;
    },
    staleTime: 60_000,
    retry: false,
  });
}
