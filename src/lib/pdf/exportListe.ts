import {
  drawHeader,
  drawFooter,
  addPageNumbers,
  ensurePdfLogo,
  getPdfChromeBodyTop,
  getPdfChromeFooterTop,
} from "@/lib/pdf/pdfChrome";
import { PDF_TABLE, getActiveTemplate } from "@/lib/pdf/pdfConfig";

export type ExportListeOptions = {
  titre: string;
  colonnes: string[];
  lignes: (string | number)[][];
  filtres?: string[];
  recap?: { label: string; valeur: string }[];
  filename?: string;
  orientation?: "portrait" | "landscape";
};

/**
 * Génère et télécharge un PDF récapitulatif d'une liste filtrée (§16).
 * En-tête FABS-CI, rappel des filtres actifs, tableau autoTable.
 */
export async function exportListePDF(opts: ExportListeOptions): Promise<void> {
  const [{ default: jsPDF }, { default: autoTable }] = await Promise.all([
    import("jspdf"),
    import("jspdf-autotable"),
  ]);
  await ensurePdfLogo();
  const orientation = opts.orientation ?? "landscape";
  const doc = new jsPDF({ orientation, unit: "mm", format: "a4" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const marginX = 14;
  const template = getActiveTemplate();

  // Charte unifiée : en-tête FABS-CI officiel (logo + société + date/heure + titre).
  drawHeader(doc, opts.titre, template);
  let cursorY = getPdfChromeBodyTop();

  // Filtres appliqués
  if (opts.filtres && opts.filtres.length > 0) {
    doc.setFont("helvetica", "bold");
    doc.setFontSize(9);
    doc.text("Filtres appliqués :", marginX, cursorY);
    cursorY += 4;
    doc.setFont("helvetica", "normal");
    doc.setFontSize(8);
    const text = opts.filtres.join("  •  ");
    const split = doc.splitTextToSize(text, pageWidth - marginX * 2);
    doc.text(split, marginX, cursorY);
    cursorY += split.length * 3.6 + 2;
  }

  // Tableau — styles unifiés (PDF_TABLE) + marges bornées par le chrome commun.
  autoTable(doc, {
    head: [opts.colonnes],
    body: opts.lignes.map((r) => r.map((c) => (c === null || c === undefined ? "" : String(c)))),
    startY: cursorY + 2,
    margin: {
      left: marginX,
      right: marginX,
      bottom: doc.internal.pageSize.getHeight() - getPdfChromeFooterTop(doc) + 4,
    },
    styles: {
      fontSize: PDF_TABLE.bodyFontSize,
      cellPadding: 2.8,
      overflow: "linebreak",
      lineWidth: 0.1,
    },
    headStyles: PDF_TABLE.headStyles,
    bodyStyles: PDF_TABLE.bodyStyles,
    alternateRowStyles: { fillColor: [245, 247, 250] },
    didDrawPage: () => {
      drawHeader(doc, opts.titre, template);
      drawFooter(doc, `${opts.lignes.length} résultat(s)`, template);
    },
  });

  // Récapitulatif optionnel après le tableau
  if (opts.recap && opts.recap.length > 0) {
    // @ts-expect-error - lastAutoTable injecté par jspdf-autotable
    const lastY: number = doc.lastAutoTable?.finalY ?? cursorY;
    const footerLimit = getPdfChromeFooterTop(doc) - 4;
    const boxWidth = 90;
    const rowH = 5.5;
    const boxHeight = 6 + opts.recap.length * rowH;
    let boxY = lastY + 6;
    if (boxY + boxHeight > footerLimit) {
      doc.addPage();
      drawHeader(doc, opts.titre, template);
      drawFooter(doc, `${opts.lignes.length} résultat(s)`, template);
      boxY = getPdfChromeBodyTop();
    }
    const boxX = pageWidth - marginX - boxWidth;
    doc.setDrawColor(200);
    doc.setFillColor(245, 247, 250);
    doc.roundedRect(boxX, boxY, boxWidth, boxHeight, 1.5, 1.5, "FD");
    doc.setFont("helvetica", "bold");
    doc.setFontSize(9);
    doc.setTextColor(30);
    doc.text("Récapitulatif", boxX + 3, boxY + 4.5);
    doc.setFont("helvetica", "normal");
    doc.setFontSize(9);
    opts.recap.forEach((r, i) => {
      const y = boxY + 4.5 + (i + 1) * rowH;
      doc.setFont("helvetica", "normal");
      doc.text(r.label, boxX + 3, y);
      doc.setFont("helvetica", "bold");
      doc.text(r.valeur, boxX + boxWidth - 3, y, { align: "right" });
    });
  }

  addPageNumbers(doc);

  const filename = (opts.filename ?? opts.titre.replace(/\s+/g, "_")) + ".pdf";
  doc.save(filename);
}
