import { useEffect } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export type ApprobationsCount = {
  total: number;
  critiques: number;
  sla_depasses: number;
};

const EMPTY: ApprobationsCount = { total: 0, critiques: 0, sla_depasses: 0 };

/**
 * Compteur global des approbations en attente + subscription Realtime.
 * Utilisé pour le badge sidebar et les toasts contextuels.
 */
export function useApprobationsCount() {
  const qc = useQueryClient();

  const query = useQuery({
    queryKey: ["approbations", "count"],
    queryFn: async (): Promise<ApprobationsCount> => {
      const { data, error } = await supabase
        .from("v_approbations_en_attente_count" as never)
        .select("total, critiques, sla_depasses")
        .maybeSingle();
      if (error) return EMPTY;
      return (data as ApprobationsCount | null) ?? EMPTY;
    },
    staleTime: 30_000,
    refetchInterval: 60_000,
  });

  useEffect(() => {
    const channel = supabase
      .channel("approbations-count")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "workflow_approvals" },
        () => {
          qc.invalidateQueries({ queryKey: ["approbations", "count"] });
          qc.invalidateQueries({ queryKey: ["approbations", "list"] });
        },
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [qc]);

  return query.data ?? EMPTY;
}
