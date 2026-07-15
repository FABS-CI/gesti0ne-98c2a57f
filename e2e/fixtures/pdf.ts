// Extraction de texte page par page avec regroupement par ligne (Y) et
// tri par X. Utilisé pour vérifier l'ordre des en-têtes sur CHAQUE page.
import { getDocument } from "pdfjs-dist/legacy/build/pdf.mjs";

export type PdfRow = { y: number; cells: { x: number; str: string }[] };

export async function extractPdfPages(buf: Buffer): Promise<PdfRow[][]> {
  const loadingTask = getDocument({
    data: new Uint8Array(buf),
    disableFontFace: true,
    isEvalSupported: false,
  });
  const doc = await loadingTask.promise;
  const pages: PdfRow[][] = [];
  const Y_TOL = 3;
  for (let p = 1; p <= doc.numPages; p++) {
    const page = await doc.getPage(p);
    const content = await page.getTextContent();
    const byRow = new Map<number, { x: number; str: string }[]>();
    for (const it of content.items as Array<{ str: string; transform: number[] }>) {
      if (!it.str.trim()) continue;
      const y = Math.round(it.transform[5] / Y_TOL) * Y_TOL;
      if (!byRow.has(y)) byRow.set(y, []);
      byRow.get(y)!.push({ x: it.transform[4], str: it.str });
    }
    const rows = Array.from(byRow.entries())
      .sort((a, b) => b[0] - a[0])
      .map(([y, cells]) => ({
        y,
        cells: cells.sort((a, b) => a.x - b.x),
      }));
    pages.push(rows);
  }
  return pages;
}

/** Sur chaque page, trouve la ligne contenant tous les en-têtes et retourne
 *  la séquence horizontale effective (triée par X). */
export function headerSequencesPerPage(
  pages: PdfRow[][],
  headers: string[],
): string[][] {
  return pages.map((rows) => {
    const target = rows.find((r) =>
      headers.every((h) => r.cells.some((c) => c.str.includes(h))),
    );
    if (!target) return [];
    return target.cells
      .map((c) => headers.find((h) => c.str.includes(h)))
      .filter((v): v is string => Boolean(v))
      .filter((h, i, arr) => arr.indexOf(h) === i);
  });
}

/** Diff lisible entre deux séquences (retourne un texte multi-lignes). */
export function diffSequence(expected: string[], actual: string[]): string {
  const lines: string[] = [];
  const n = Math.max(expected.length, actual.length);
  let firstDiff = -1;
  for (let i = 0; i < n; i++) {
    const e = expected[i] ?? "∅";
    const a = actual[i] ?? "∅";
    const ok = e === a;
    if (!ok && firstDiff === -1) firstDiff = i;
    lines.push(`${ok ? "  " : "✗ "}${String(i).padStart(3)}  attendu="${e}"   reçu="${a}"`);
  }
  if (firstDiff >= 0) lines.unshift(`Première divergence à l'index ${firstDiff}.`);
  return lines.join("\n");
}