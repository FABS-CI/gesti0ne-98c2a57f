import type { ExerciceStatut } from "@/contexts/ExerciceContext";

export const STATUT_LABEL: Record<ExerciceStatut, string> = {
  preparation: "Préparation",
  actif: "Actif",
  cloture_en_cours: "Clôture en cours",
  cloture: "Clôturé",
  archive: "Archivé",
};

export type PreviewResult = {
  exercice: { code: string; date_debut: string; date_fin: string };
  exercice_suivant: { code: string; exercice_id: string } | null;
  clients: {
    debiteurs_count: number;
    crediteurs_count: number;
    total_debit: number;
    total_credit: number;
  };
  fournisseurs: {
    debiteurs_count: number;
    crediteurs_count: number;
    total_debit: number;
    total_credit: number;
  };
  blocages: { code: string; severite: "warning" | "error"; message: string }[];
  peut_cloturer: boolean;
};

export type EditingExercice = {
  exercice_id: string;
  code: string;
  date_debut: string;
  date_fin: string;
  statut: ExerciceStatut;
};
