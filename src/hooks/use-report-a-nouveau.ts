import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { useExerciceConsulteId } from "@/contexts/ExerciceContext";

/**
 * Report à-nouveau (opening balance) sur l'exercice consulté.
 * - "client" → soldes_ouverture_clients (positif = client débiteur, négatif = avance)
 * - "fournisseur" → soldes_ouverture_fournisseurs (positif = fournisseur créditeur, négatif = avance)
 */
export function useReportANouveau(type: "client" | "fournisseur", entityId: string | undefined) {
  const exerciceId = useExerciceConsulteId();

  return useQuery({
    queryKey: ["report-a-nouveau", type, entityId, exerciceId],
    enabled: !!entityId && !!exerciceId,
    queryFn: async () => {
      if (type === "client") {
        const { data, error } = await supabase
          .from("soldes_ouverture_clients")
          .select("montant")
          .eq("client_id", entityId!)
          .eq("exercice_id", exerciceId!)
          .maybeSingle();
        if (error) throw error;
        return { montant: data ? Number(data.montant) : 0 };
      }
      const { data, error } = await supabase
        .from("soldes_ouverture_fournisseurs")
        .select("montant")
        .eq("fournisseur_id", entityId!)
        .eq("exercice_id", exerciceId!)
        .maybeSingle();
      if (error) throw error;
      return { montant: data ? Number(data.montant) : 0 };
    },
  });
}
