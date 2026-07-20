/**
 * Export CSV / Excel en streaming pour de très grandes listes.
 *
 * - Récupère les données page par page via une fonction fournie par
 *   l'appelant (typiquement une requête Supabase paginée via `.range()`).
 * - Écrit les lignes progressivement dans un ou plusieurs Blob afin
 *   d'éviter de charger 100k+ lignes en mémoire d'un seul coup.
 * - Utilise CSV UTF-8 (BOM) pour compatibilité Excel/LibreOffice ou XLSX
 *   via SheetJS (chargement dynamique pour ne pas grossir le bundle).
 *
 * Charte ERP FABS-CI §22 (rapports) :
 *  - En-têtes traduits FR
 *  - Nom de fichier horodaté : `slug-YYYYMMDD-HHMM.ext`
 *  - Progression exposée via callback `onProgress` pour brancher un
 *    toast/toolbar de suivi.
 */

export type ExportFormat = "csv" | "xlsx";

export interface ExportColumn<Row> {
  key: string;
  label: string;
  /** Valeur à écrire dans la cellule (défaut : row[key]). */
  accessor?: (row: Row) => unknown;
  /** Format numérique optionnel (XLSX uniquement). */
  numFmt?: string;
}

export interface StreamExportOptions<Row> {
  /** Nom de fichier sans extension. Un horodatage est ajouté. */
  filename: string;
  format: ExportFormat;
  columns: ExportColumn<Row>[];
  /** Récupère une page (0-based). Retourne `[]` quand plus rien. */
  fetchPage: (page: number, pageSize: number) => Promise<Row[]>;
  /** Taille de page. Défaut : 1000 (limite raisonnable Supabase). */
  pageSize?: number;
  /** Nombre total estimé (pour progression). Optionnel. */
  total?: number;
  onProgress?: (info: { fetched: number; total?: number }) => void;
  /** Nom de la feuille (XLSX). Défaut : "Export". */
  sheetName?: string;
}

function timestamp() {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}`;
}

function csvEscape(v: unknown): string {
  if (v == null) return "";
  const s = typeof v === "string" ? v : String(v);
  if (/[",;\r\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

async function streamCsv<Row>(opts: StreamExportOptions<Row>) {
  const { columns, fetchPage, onProgress, total } = opts;
  const pageSize = opts.pageSize ?? 1000;
  const chunks: BlobPart[] = ["\uFEFF"]; // BOM UTF-8
  chunks.push(columns.map((c) => csvEscape(c.label)).join(";") + "\r\n");

  let page = 0;
  let fetched = 0;
  for (;;) {
    const rows = await fetchPage(page, pageSize);
    if (rows.length === 0) break;
    for (const row of rows) {
      const line = columns
        .map((c) => {
          const raw = c.accessor
            ? c.accessor(row)
            : (row as Record<string, unknown>)[c.key];
          return csvEscape(raw);
        })
        .join(";");
      chunks.push(line + "\r\n");
    }
    fetched += rows.length;
    onProgress?.({ fetched, total });
    if (rows.length < pageSize) break;
    page += 1;
  }

  const blob = new Blob(chunks, { type: "text/csv;charset=utf-8" });
  triggerDownload(blob, `${opts.filename}-${timestamp()}.csv`);
  return { fetched };
}

async function streamXlsx<Row>(opts: StreamExportOptions<Row>) {
  const { columns, fetchPage, onProgress, total } = opts;
  const pageSize = opts.pageSize ?? 1000;
  const XLSX = await import("xlsx");

  const aoa: unknown[][] = [columns.map((c) => c.label)];
  let page = 0;
  let fetched = 0;
  for (;;) {
    const rows = await fetchPage(page, pageSize);
    if (rows.length === 0) break;
    for (const row of rows) {
      aoa.push(
        columns.map((c) =>
          c.accessor ? c.accessor(row) : (row as Record<string, unknown>)[c.key],
        ),
      );
    }
    fetched += rows.length;
    onProgress?.({ fetched, total });
    if (rows.length < pageSize) break;
    page += 1;
  }

  const ws = XLSX.utils.aoa_to_sheet(aoa);
  // largeurs auto basiques
  ws["!cols"] = columns.map((c) => ({
    wch: Math.min(40, Math.max(10, c.label.length + 2)),
  }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, opts.sheetName ?? "Export");
  const out = XLSX.write(wb, { bookType: "xlsx", type: "array" });
  const blob = new Blob([out], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  triggerDownload(blob, `${opts.filename}-${timestamp()}.xlsx`);
  return { fetched };
}

export async function streamExport<Row>(opts: StreamExportOptions<Row>) {
  return opts.format === "xlsx" ? streamXlsx(opts) : streamCsv(opts);
}
