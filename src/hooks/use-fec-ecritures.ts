import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import type { EcritureFec } from "@/lib/fec-helpers";

export function useFecEcritures(dateFrom: string, dateTo: string, enabled: boolean) {
  return useQuery({
    queryKey: ["fec-ecritures", dateFrom, dateTo],
    enabled,
    queryFn: async (): Promise<EcritureFec[]> => {
      const { data, error } = await supabase
        .from("ecritures_comptables")
        .select(
          "ecriture_id, reference, date_ecriture, journal, libelle, lettrage, ecriture_lignes(compte, compte_libelle, debit, credit)",
        )
        .gte("date_ecriture", dateFrom)
        .lte("date_ecriture", dateTo)
        .order("date_ecriture", { ascending: true });
      if (error) throw error;
      return (data ?? []) as EcritureFec[];
    },
  });
}
