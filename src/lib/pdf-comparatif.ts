import { formatFCFA } from "@/lib/format";

export type SortKey = "code" | "ca" | "encaisse" | "achats" | "resultat";

export type ComparatifRow = {
  code: string;
  nbCommandes: number;
  nbFactures: number;
  ca: number;
  encaisse: number;
  achats: number;
  resultat: number;
};

export type BuildPdfMetaInput = {
  userEmail: string;
  timestamp: string; // affichable
  rows: ComparatifRow[]; // dans l'ordre affiché (filtres + tri appliqués)
  sortKey: SortKey;
  sortDir: "asc" | "desc";
  showPct: boolean;
  contexte?: string;
};

export type PdfMeta = {
  fileBase: string;
  pageTitle: string;
  headers: string[];
  rows: (string | number)[][];
  summary: { label: string; value: string }[];
};

const SORT_LABEL: Record<SortKey, string> = {
  code: "Exercice",
  ca: "CA facturé",
  encaisse: "Encaissé",
  achats: "Achats",
  resultat: "Résultat",
};

/**
 * Construit une structure PDF (titre + entêtes + lignes + méta) alignée
 * exactement sur l'affichage écran. Fonction pure — testable sans jsPDF.
 */
export function buildPdfMeta(input: BuildPdfMetaInput): PdfMeta {
  const { userEmail, timestamp, rows, sortKey, sortDir, showPct, contexte } = input;
  const dirLabel = sortDir === "asc" ? "croissant" : "décroissant";
  const baseHeaders = [
    "Exercice",
    "Commandes",
    "Factures",
    "CA facturé",
    "Encaissé",
    "Achats",
    "Résultat",
  ];
  const headers = showPct ? [...baseHeaders, "% évolution CA"] : baseHeaders;

  const pdfRows: (string | number)[][] = rows.map((r, idx) => {
    const base: (string | number)[] = [
      r.code,
      r.nbCommandes,
      r.nbFactures,
      formatFCFA(r.ca),
      formatFCFA(r.encaisse),
      formatFCFA(r.achats),
      formatFCFA(r.resultat),
    ];
    if (showPct) {
      const prev = rows[idx - 1];
      const pct =
        prev && prev.ca > 0 ? `${(((r.ca - prev.ca) / prev.ca) * 100).toFixed(1)} %` : "—";
      base.push(pct);
    }
    return base;
  });

  const codesAffiches = rows.map((r) => r.code).join(", ") || "—";
  const caCumule = rows.reduce((s, r) => s + r.ca, 0);
  const resultatCumule = rows.reduce((s, r) => s + r.resultat, 0);

  return {
    fileBase: "comparatif_exercices",
    pageTitle: "COMPARATIF MULTI-EXERCICES",
    headers,
    rows: pdfRows,
    summary: [
      { label: "Généré le", value: timestamp },
      { label: "Généré par", value: userEmail },
      { label: "Contexte", value: contexte ?? "Vue interne — tous clients" },
      { label: "Exercices affichés", value: codesAffiches },
      { label: "Exercices comparés", value: String(rows.length) },
      { label: "Tri", value: `${SORT_LABEL[sortKey]} (${dirLabel})` },
      { label: "% évolution", value: showPct ? "Inclus" : "Masqués" },
      { label: "CA cumulé", value: formatFCFA(caCumule) },
      { label: "Résultat cumulé", value: formatFCFA(resultatCumule) },
    ],
  };
}
