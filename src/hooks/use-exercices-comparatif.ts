import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export type ComparatifRow = {
  exercice_id: string;
  code: string;
  ca: number;
  encaisse: number;
  achats: number;
  resultat: number;
  nbCommandes: number;
  nbFactures: number;
};

export type ExerciceLite = { exercice_id: string; code: string };

export function useExercicesComparatif(exercices: ExerciceLite[]) {
  return useQuery({
    enabled: exercices.length > 0,
    queryKey: ["exercices-comparatif", exercices.map((e) => e.exercice_id).join(",")],
    queryFn: async () => {
      // Agrégation 100% serveur : une seule RPC couvre les N exercices.
      const ids = exercices.map((e) => e.exercice_id);
      const { data, error } = await supabase.rpc("exercices_comparatif" as never, {
        _exercice_ids: ids,
      } as never);
      if (error) throw error;
      const rows = (data ?? []) as Array<{
        exercice_id: string;
        ca: number | string;
        encaisse: number | string;
        achats: number | string;
        nb_commandes: number | string;
        nb_factures: number | string;
      }>;
      const byId = new Map(rows.map((r) => [r.exercice_id, r]));
      const results: ComparatifRow[] = exercices.map((ex) => {
        const r = byId.get(ex.exercice_id);
        const ca = Number(r?.ca ?? 0);
        const achats = Number(r?.achats ?? 0);
        return {
          exercice_id: ex.exercice_id,
          code: ex.code,
          ca,
          encaisse: Number(r?.encaisse ?? 0),
          achats,
          resultat: ca - achats,
          nbCommandes: Number(r?.nb_commandes ?? 0),
          nbFactures: Number(r?.nb_factures ?? 0),
        };
      });
      return results.sort((a, b) => a.code.localeCompare(b.code));
    },
  });
}
