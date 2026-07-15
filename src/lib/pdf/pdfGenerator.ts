import type jsPDF from "jspdf";
import { formatFCFA } from "@/lib/format";
import {
  PDF_COLORS,
  PDF_MARGINS,
  PDF_TABLE,
  getActiveTemplate,
  type PdfTemplate,
} from "@/lib/pdf/pdfConfig";
import {
  drawHeader as sharedDrawHeader,
  drawFooter as sharedDrawFooter,
  addPageNumbers as sharedAddPageNumbers,
  getPdfChromeBodyTop,
  ensurePdfLogo,
  ensurePdfQr,
  clearPdfQr,
} from "@/lib/pdf/pdfChrome";

async function loadPdfLibs() {
  const [{ default: JsPDF }, { default: autoTable }] = await Promise.all([
    import("jspdf"),
    import("jspdf-autotable"),
  ]);
  return { JsPDF, autoTable };
}

// ----------------------------------------------------------------------------
// NOTE — Les générateurs jsPDF pour Facture / Bon de Livraison / Bulletin de Paie
// ont été supprimés. Ils dupliquaient les versions pdf-lib V10 de fabsTemplates.ts
// (qui sont les seules utilisées en production, avec QR code + chrome officiel).
// Pour ces 3 types, importer depuis "@/lib/pdf/fabsTemplates" :
//   - generateFacturePDF
//   - generateBonLivraisonPDF
//   - generateBulletinPaiePDF
// ----------------------------------------------------------------------------

function header(doc: jsPDF, titre: string, t: PdfTemplate) {
  sharedDrawHeader(doc, titre, t);
}

function footer(doc: jsPDF, mentions: string, t: PdfTemplate) {
  sharedDrawFooter(doc, mentions, t);
}

function addPageNumbers(doc: jsPDF) {
  sharedAddPageNumbers(doc);
}

export async function generateJournalComptablePDF(
  ecritures: {
    reference: string;
    date_ecriture: string;
    journal: string;
    libelle: string;
    lettrage: string | null;
    ecriture_lignes: { compte: string; compte_libelle: string; debit: number; credit: number }[];
  }[],
  filtres?: { dateFrom?: string; dateTo?: string; journal?: string; lettrage?: string },
  mode: "save" | "preview" = "save",
): Promise<string | void> {
  await ensurePdfLogo();
  await ensurePdfQr(buildJournalFileName(filtres).replace(/\.pdf$/, ""));

  const { JsPDF, autoTable } = await loadPdfLibs();
  const doc = new JsPDF({ orientation: "landscape" });
  const t = getActiveTemplate();

  const parts: string[] = [];
  if (filtres?.dateFrom) parts.push(`Du ${filtres.dateFrom}`);
  if (filtres?.dateTo) parts.push(`Au ${filtres.dateTo}`);
  if (filtres?.journal && filtres.journal !== "all") parts.push(`Journal ${filtres.journal}`);
  if (filtres?.lettrage && filtres.lettrage !== "all")
    parts.push(filtres.lettrage === "lettre" ? "Lettrés" : "Non lettrés");
  const sousTitre = parts.length ? parts.join(" · ") : "Toutes les écritures";
  const generatedAt = `Généré le ${new Date().toLocaleString("fr-FR")}`;

  let totalDebit = 0;
  let totalCredit = 0;
  const rows: string[][] = [];
  ecritures.forEach((e) => {
    e.ecriture_lignes.forEach((l) => {
      totalDebit += Number(l.debit);
      totalCredit += Number(l.credit);
      rows.push([
        e.reference,
        e.date_ecriture,
        e.journal,
        e.libelle,
        e.lettrage ?? "—",
        l.compte,
        l.compte_libelle,
        Number(l.debit) > 0 ? formatFCFA(Number(l.debit)) : "",
        Number(l.credit) > 0 ? formatFCFA(Number(l.credit)) : "",
      ]);
    });
  });

  autoTable(doc, {
    startY: getPdfChromeBodyTop(),
    head: [["Pièce", "Date", "Jrn", "Libellé", "Lettr.", "Compte", "Intitulé", "Débit", "Crédit"]],
    body: rows,
    foot: [["", "", "", "", "", "", "TOTAUX", formatFCFA(totalDebit), formatFCFA(totalCredit)]],
    headStyles: PDF_TABLE.headStyles,
    footStyles: PDF_TABLE.footStyles,
    styles: { fontSize: PDF_TABLE.journalFontSize, cellPadding: 2.6, overflow: "linebreak" },
    bodyStyles: PDF_TABLE.bodyStyles,
    columnStyles: { 7: { halign: "right" }, 8: { halign: "right" } },
    margin: { ...PDF_MARGINS.journal, top: getPdfChromeBodyTop(), bottom: 52 },
    didDrawPage: () => {
      // En-tête professionnel sur chaque page
      header(doc, "JOURNAL COMPTABLE", t);
      doc.setFontSize(9);
      doc.setFont("helvetica", "normal");
      doc.setTextColor(...PDF_COLORS.black);
      doc.text(sousTitre, 14, 36);
      // Date/heure de génération (à droite)
      doc.setFontSize(8);
      doc.setTextColor(...PDF_COLORS.muted);
      doc.text(generatedAt, doc.internal.pageSize.getWidth() - 14, 36, { align: "right" });
      // Pied de page + numéro de page sur chaque page
      footer(doc, "Journal comptable généré conformément au plan SYSCOHADA.", t);
    },
  });

  addPageNumbers(doc);

  if (mode === "preview") {
    const url = doc.output("bloburl").toString();
    clearPdfQr();
    return url;
  }
  doc.save(buildJournalFileName(filtres));
  clearPdfQr();
}

/** Nom de fichier basé sur la période et les filtres : JournalComptable_YYYY-MM-DD_YYYY-MM-DD[_JRN][_lettres].pdf */
export function buildJournalFileName(filtres?: {
  dateFrom?: string;
  dateTo?: string;
  journal?: string;
  lettrage?: string;
}): string {
  const parts: string[] = ["JournalComptable"];
  parts.push(filtres?.dateFrom || "debut");
  parts.push(filtres?.dateTo || "fin");
  if (filtres?.journal && filtres.journal !== "all") parts.push(filtres.journal);
  if (filtres?.lettrage && filtres.lettrage !== "all")
    parts.push(filtres.lettrage === "lettre" ? "lettres" : "non-lettres");
  return `${parts.join("_")}.pdf`;
}

// ----------------------------------------------------------------------------
// Balance générale (SYSCOHADA) — PDF pro paysage
// ----------------------------------------------------------------------------
export type BalanceRowPdf = {
  compte: string;
  compte_libelle: string;
  debit: number;
  credit: number;
  solde: number;
};

export async function generateBalancePDF(
  rows: BalanceRowPdf[],
  filtres?: { dateFrom?: string; dateTo?: string },
  mode: "save" | "blob" = "save",
): Promise<Blob | void> {
  await ensurePdfLogo();
  await ensurePdfQr(buildBalanceFileName(filtres).replace(/\.pdf$/, ""));
  const { JsPDF, autoTable } = await loadPdfLibs();
  const doc = new JsPDF({ orientation: "landscape" });
  const t = getActiveTemplate();

  const parts: string[] = [];
  if (filtres?.dateFrom) parts.push(`Du ${filtres.dateFrom}`);
  if (filtres?.dateTo) parts.push(`Au ${filtres.dateTo}`);
  const sousTitre = parts.length ? parts.join(" · ") : "Toutes périodes";
  const generatedAt = `Généré le ${new Date().toLocaleString("fr-FR")}`;

  const totalD = rows.reduce((s, r) => s + r.debit, 0);
  const totalC = rows.reduce((s, r) => s + r.credit, 0);
  const body = rows.map((r) => [
    r.compte,
    r.compte_libelle,
    formatFCFA(r.debit),
    formatFCFA(r.credit),
    formatFCFA(r.solde),
  ]);

  autoTable(doc, {
    startY: getPdfChromeBodyTop(),
    head: [["Compte", "Intitulé", "Débit", "Crédit", "Solde"]],
    body,
    foot: [["", "TOTAUX", formatFCFA(totalD), formatFCFA(totalC), formatFCFA(totalD - totalC)]],
    headStyles: PDF_TABLE.headStyles,
    footStyles: PDF_TABLE.footStyles,
    styles: { fontSize: PDF_TABLE.journalFontSize, cellPadding: 2.6, overflow: "linebreak" },
    bodyStyles: PDF_TABLE.bodyStyles,
    columnStyles: { 2: { halign: "right" }, 3: { halign: "right" }, 4: { halign: "right" } },
    margin: { ...PDF_MARGINS.journal, top: getPdfChromeBodyTop(), bottom: 52 },
    didDrawPage: () => {
      header(doc, "BALANCE GÉNÉRALE", t);
      doc.setFontSize(9);
      doc.setFont("helvetica", "normal");
      doc.setTextColor(...PDF_COLORS.black);
      doc.text(sousTitre, 14, 36);
      doc.setFontSize(8);
      doc.setTextColor(...PDF_COLORS.muted);
      doc.text(generatedAt, doc.internal.pageSize.getWidth() - 14, 36, { align: "right" });
      footer(doc, "Balance générale — Plan comptable SYSCOHADA.", t);
    },
  });
  addPageNumbers(doc);
  if (mode === "blob") {
    const blob = doc.output("blob");
    clearPdfQr();
    return blob;
  }
  doc.save(buildBalanceFileName(filtres));
  clearPdfQr();
}

export function buildBalanceFileName(filtres?: { dateFrom?: string; dateTo?: string }): string {
  return `Balance_${filtres?.dateFrom || "debut"}_${filtres?.dateTo || "fin"}.pdf`;
}

// ----------------------------------------------------------------------------
// Grand livre (SYSCOHADA) — PDF pro paysage, tri par compte
// ----------------------------------------------------------------------------
export type GrandLivreLignePdf = {
  compte: string;
  compte_libelle: string;
  date_ecriture: string;
  journal: string;
  reference: string;
  libelle: string;
  debit: number;
  credit: number;
  solde: number;
};

export async function generateGrandLivrePDF(
  lignes: GrandLivreLignePdf[],
  filtres?: { dateFrom?: string; dateTo?: string; compte?: string },
  mode: "save" | "blob" = "save",
): Promise<Blob | void> {
  await ensurePdfLogo();
  await ensurePdfQr(buildGrandLivreFileName(filtres).replace(/\.pdf$/, ""));
  const { JsPDF, autoTable } = await loadPdfLibs();
  const doc = new JsPDF({ orientation: "landscape" });
  const t = getActiveTemplate();

  const parts: string[] = [];
  if (filtres?.dateFrom) parts.push(`Du ${filtres.dateFrom}`);
  if (filtres?.dateTo) parts.push(`Au ${filtres.dateTo}`);
  if (filtres?.compte && filtres.compte !== "all") parts.push(`Compte ${filtres.compte}`);
  const sousTitre = parts.length ? parts.join(" · ") : "Tous les comptes";
  const generatedAt = `Généré le ${new Date().toLocaleString("fr-FR")}`;

  const body = lignes.map((l) => [
    l.compte,
    l.date_ecriture,
    l.journal,
    l.reference,
    l.libelle,
    l.debit ? formatFCFA(l.debit) : "",
    l.credit ? formatFCFA(l.credit) : "",
    formatFCFA(l.solde),
  ]);
  const totalD = lignes.reduce((s, l) => s + l.debit, 0);
  const totalC = lignes.reduce((s, l) => s + l.credit, 0);

  autoTable(doc, {
    startY: getPdfChromeBodyTop(),
    head: [["Compte", "Date", "Jrn", "Pièce", "Libellé", "Débit", "Crédit", "Solde"]],
    body,
    foot: [
      [
        "",
        "",
        "",
        "",
        "TOTAUX",
        formatFCFA(totalD),
        formatFCFA(totalC),
        formatFCFA(totalD - totalC),
      ],
    ],
    headStyles: PDF_TABLE.headStyles,
    footStyles: PDF_TABLE.footStyles,
    styles: { fontSize: PDF_TABLE.journalFontSize, cellPadding: 2.6, overflow: "linebreak" },
    bodyStyles: PDF_TABLE.bodyStyles,
    columnStyles: { 5: { halign: "right" }, 6: { halign: "right" }, 7: { halign: "right" } },
    margin: { ...PDF_MARGINS.journal, top: getPdfChromeBodyTop(), bottom: 52 },
    didDrawPage: () => {
      header(doc, "GRAND LIVRE", t);
      doc.setFontSize(9);
      doc.setFont("helvetica", "normal");
      doc.setTextColor(...PDF_COLORS.black);
      doc.text(sousTitre, 14, 36);
      doc.setFontSize(8);
      doc.setTextColor(...PDF_COLORS.muted);
      doc.text(generatedAt, doc.internal.pageSize.getWidth() - 14, 36, { align: "right" });
      footer(doc, "Grand livre — Plan comptable SYSCOHADA.", t);
    },
  });
  addPageNumbers(doc);
  if (mode === "blob") {
    const blob = doc.output("blob");
    clearPdfQr();
    return blob;
  }
  doc.save(buildGrandLivreFileName(filtres));
  clearPdfQr();
}

export function buildGrandLivreFileName(filtres?: {
  dateFrom?: string;
  dateTo?: string;
  compte?: string;
}): string {
  const parts = ["GrandLivre", filtres?.dateFrom || "debut", filtres?.dateTo || "fin"];
  if (filtres?.compte && filtres.compte !== "all") parts.push(filtres.compte);
  return `${parts.join("_")}.pdf`;
}
