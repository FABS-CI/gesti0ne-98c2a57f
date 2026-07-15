import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export type ExerciceStatut = "preparation" | "actif" | "cloture_en_cours" | "cloture" | "archive";

export interface Exercice {
  exercice_id: string;
  code: string;
  date_debut: string;
  date_fin: string;
  statut: ExerciceStatut;
  is_actif: boolean;
}

interface ExerciceContextValue {
  exercices: Exercice[];
  exerciceActif: Exercice | null;
  exerciceConsulte: Exercice | null;
  exerciceConsulteId: string | null;
  setExerciceConsulteId: (id: string) => void;
  isReadOnly: boolean;
  isLoading: boolean;
}

const STORAGE_KEY = "fabsci.exerciceConsulteId";

const ExerciceContext = createContext<ExerciceContextValue | undefined>(undefined);

export function ExerciceProvider({ children }: { children: ReactNode }) {
  const { data: exercices = [], isLoading } = useQuery({
    queryKey: ["exercices", "all"],
    staleTime: 5 * 60_000,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("exercices")
        .select("exercice_id, code, date_debut, date_fin, statut, is_actif")
        .order("date_debut", { ascending: false });
      if (error) throw error;
      return (data ?? []) as Exercice[];
    },
  });

  const exerciceActif = useMemo(() => exercices.find((e) => e.is_actif) ?? null, [exercices]);

  const [exerciceConsulteId, setExerciceConsulteIdState] = useState<string | null>(() => {
    if (typeof window === "undefined") return null;
    return window.localStorage.getItem(STORAGE_KEY);
  });

  // Défaut = exercice actif quand la liste est chargée et rien n'est stocké
  useEffect(() => {
    if (!exerciceActif) return;
    if (!exerciceConsulteId) {
      setExerciceConsulteIdState(exerciceActif.exercice_id);
      return;
    }
    // Si l'id stocké n'existe plus, retomber sur l'actif
    if (!exercices.some((e) => e.exercice_id === exerciceConsulteId)) {
      setExerciceConsulteIdState(exerciceActif.exercice_id);
    }
  }, [exerciceActif, exerciceConsulteId, exercices]);

  const setExerciceConsulteId = useCallback((id: string) => {
    setExerciceConsulteIdState(id);
    if (typeof window !== "undefined") {
      window.localStorage.setItem(STORAGE_KEY, id);
    }
  }, []);

  const exerciceConsulte = useMemo(
    () => exercices.find((e) => e.exercice_id === exerciceConsulteId) ?? null,
    [exercices, exerciceConsulteId],
  );

  const isReadOnly = useMemo(() => {
    if (!exerciceConsulte || !exerciceActif) return false;
    return exerciceConsulte.exercice_id !== exerciceActif.exercice_id;
  }, [exerciceConsulte, exerciceActif]);

  const value: ExerciceContextValue = {
    exercices,
    exerciceActif,
    exerciceConsulte,
    exerciceConsulteId,
    setExerciceConsulteId,
    isReadOnly,
    isLoading,
  };

  return <ExerciceContext.Provider value={value}>{children}</ExerciceContext.Provider>;
}

export function useExercice() {
  const ctx = useContext(ExerciceContext);
  if (!ctx) throw new Error("useExercice doit être utilisé dans <ExerciceProvider>");
  return ctx;
}

/**
 * Retourne l'id de l'exercice consulté — à utiliser dans les queryKeys et filtres.
 */
export function useExerciceConsulteId(): string | null {
  return useExercice().exerciceConsulteId;
}
