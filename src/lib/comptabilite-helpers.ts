export type LigneEcriture = {
  ligne_id: string;
  compte: string;
  compte_libelle: string;
  debit: number;
  credit: number;
};

export type Ecriture = {
  ecriture_id: string;
  reference: string;
  date_ecriture: string;
  journal: string;
  libelle: string;
  source_type: string | null;
  lettrage: string | null;
  montant_total: number;
  ecriture_lignes: LigneEcriture[];
};

export const JOURNAL_COLORS: Record<string, string> = {
  VT: "#F97316",
  BQ: "#0A2540",
  CA: "#10B981",
  OD: "#64748B",
};

export type JournalFiltersState = {
  dateFrom: string;
  dateTo: string;
  journal: string;
  lettrage: string;
};

export function validateJournalFilters(
  ecritures: unknown[],
  { dateFrom, dateTo }: Pick<JournalFiltersState, "dateFrom" | "dateTo">,
): string | null {
  if (!ecritures.length) return "Aucune écriture à exporter pour ces filtres.";
  if (dateFrom && Number.isNaN(Date.parse(dateFrom))) return "La date « Du » est invalide.";
  if (dateTo && Number.isNaN(Date.parse(dateTo))) return "La date « Au » est invalide.";
  if (dateFrom && dateTo && dateFrom > dateTo)
    return "La date « Du » doit précéder la date « Au ».";
  if (dateTo && dateTo > new Date().toISOString().slice(0, 10))
    return "La date « Au » ne peut pas être dans le futur.";
  return null;
}

export function buildPeriodeLabel({
  dateFrom,
  dateTo,
  journal,
  lettrage,
}: JournalFiltersState): string {
  const parts: string[] = [];
  if (dateFrom) parts.push(`Du ${dateFrom}`);
  if (dateTo) parts.push(`au ${dateTo}`);
  if (journal !== "all") parts.push(`Journal ${journal}`);
  if (lettrage !== "all") parts.push(lettrage === "lettre" ? "Lettrés" : "Non lettrés");
  return parts.length ? parts.join(" · ") : "Toutes les écritures";
}
