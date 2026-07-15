import { formatFCFA } from "@/lib/format";
import { paramMap } from "@/lib/paie/parametres-api";
import { runEngine } from "@/lib/paie/engine";
import { PDF_COLORS, PDF_MARGINS, PDF_TABLE, getActiveTemplate } from "@/lib/pdf/pdfConfig";
import {
  drawHeader as sharedDrawHeader,
  drawFooter as sharedDrawFooter,
  addPageNumbers as sharedAddPageNumbers,
  getPdfChromeBodyTop,
  ensurePdfLogo,
  ensurePdfQr,
  clearPdfQr,
} from "@/lib/pdf/pdfChrome";

export type Bulletin = {
  bulletin_id: string;
  employe_nom: string | null;
  periode: string;
  salaire_brut: number;
  retenues: number;
  salaire_net: number;
};

export type DeclLigne = {
  employe: string;
  brut: number;
  cnpsSalarie: number;
  cnpsPatronal: number;
  its: number;
  cn: number;
  cmuSalarie: number;
  cmuPatronal: number;
  net: number;
};

export type DeclTotaux = Omit<DeclLigne, "employe">;

export type PdfOpts = {
  title: string;
  subtitle: string;
  footerText: string;
  fileName: string;
  head: string[][];
  body: string[][];
  foot: string[][];
};

export function slug(s: string): string {
  return s.replace(/\s+/g, "_").replace(/[^\w-]/g, "");
}

export function computeLignes(
  bulletins: Bulletin[] | undefined,
  parametres: Parameters<typeof runEngine>[1] | undefined,
  rubriques: Parameters<typeof runEngine>[2] | undefined,
): DeclLigne[] {
  if (!bulletins || !parametres || !rubriques) return [];
  return bulletins.map((b) => {
    const r = runEngine({ salaireBase: Number(b.salaire_brut) || 0 }, parametres, rubriques);
    return {
      employe: b.employe_nom ?? "—",
      brut: r.salaireBrut,
      cnpsSalarie: r.cnpsSalarie,
      cnpsPatronal: r.cnpsPatronal,
      its: r.its,
      cn: r.cn,
      cmuSalarie: r.cmuSalarie,
      cmuPatronal: r.cmuPatronal,
      net: r.salaireNet,
    };
  });
}

export function computeTotaux(lignes: DeclLigne[]): DeclTotaux {
  return lignes.reduce<DeclTotaux>(
    (acc, l) => ({
      brut: acc.brut + l.brut,
      cnpsSalarie: acc.cnpsSalarie + l.cnpsSalarie,
      cnpsPatronal: acc.cnpsPatronal + l.cnpsPatronal,
      its: acc.its + l.its,
      cn: acc.cn + l.cn,
      cmuSalarie: acc.cmuSalarie + l.cmuSalarie,
      cmuPatronal: acc.cmuPatronal + l.cmuPatronal,
      net: acc.net + l.net,
    }),
    {
      brut: 0,
      cnpsSalarie: 0,
      cnpsPatronal: 0,
      its: 0,
      cn: 0,
      cmuSalarie: 0,
      cmuPatronal: 0,
      net: 0,
    },
  );
}

export function buildDeclOptions(
  periode: string,
  lignes: DeclLigne[],
  totaux: DeclTotaux,
  parametres: Parameters<typeof runEngine>[1] | undefined,
) {
  const rate = (code: string, fallback: number) =>
    parametres ? (paramMap(parametres)[code] ?? fallback) : fallback;

  const cnps: PdfOpts = {
    title: "DÉCLARATION CNPS",
    subtitle: `Période ${periode}`,
    footerText:
      "Déclaration mensuelle CNPS — Retraite, Prestations Familiales, Accident du Travail.",
    fileName: `Declaration_CNPS_${slug(periode)}.pdf`,
    head: [
      ["Employé", "Brut", "CNPS Sal.", "CNPS Patr.", "PF+AT (estim.)", "CMU Sal.", "CMU Patr."],
    ],
    body: lignes.map((l) => [
      l.employe,
      formatFCFA(l.brut),
      formatFCFA(l.cnpsSalarie),
      formatFCFA(l.cnpsPatronal),
      formatFCFA(
        Math.round((l.brut * (rate("CNPS_PATRONAL_PF", 5.75) + rate("CNPS_PATRONAL_AT", 2))) / 100),
      ),
      formatFCFA(l.cmuSalarie),
      formatFCFA(l.cmuPatronal),
    ]),
    foot: [
      [
        "TOTAUX",
        formatFCFA(totaux.brut),
        formatFCFA(totaux.cnpsSalarie),
        formatFCFA(totaux.cnpsPatronal),
        formatFCFA(
          Math.round(
            (totaux.brut * (rate("CNPS_PATRONAL_PF", 5.75) + rate("CNPS_PATRONAL_AT", 2))) / 100,
          ),
        ),
        formatFCFA(totaux.cmuSalarie),
        formatFCFA(totaux.cmuPatronal),
      ],
    ],
  };

  const its: PdfOpts = {
    title: "DÉCLARATION ITS / CN",
    subtitle: `Période ${periode}`,
    footerText:
      "Impôt sur Traitements et Salaires + Contribution Nationale — Reversement mensuel DGI.",
    fileName: `Declaration_ITS_${slug(periode)}.pdf`,
    head: [["Employé", "Brut", "ITS", "CN", "Total à reverser"]],
    body: lignes.map((l) => [
      l.employe,
      formatFCFA(l.brut),
      formatFCFA(l.its),
      formatFCFA(l.cn),
      formatFCFA(l.its + l.cn),
    ]),
    foot: [
      [
        "TOTAUX",
        formatFCFA(totaux.brut),
        formatFCFA(totaux.its),
        formatFCFA(totaux.cn),
        formatFCFA(totaux.its + totaux.cn),
      ],
    ],
  };

  const disa: PdfOpts = {
    title: "DISA — DÉCLARATION SOCIALE ANNUELLE (Synthèse)",
    subtitle: `Période ${periode}`,
    footerText:
      "Récapitulatif employé — Assiette CNPS, contributions salariales et patronales, net perçu.",
    fileName: `DISA_${slug(periode)}.pdf`,
    head: [["Employé", "Brut", "CNPS Sal.", "CNPS Patr.", "ITS", "CN", "CMU", "Net"]],
    body: lignes.map((l) => [
      l.employe,
      formatFCFA(l.brut),
      formatFCFA(l.cnpsSalarie),
      formatFCFA(l.cnpsPatronal),
      formatFCFA(l.its),
      formatFCFA(l.cn),
      formatFCFA(l.cmuSalarie + l.cmuPatronal),
      formatFCFA(l.net),
    ]),
    foot: [
      [
        "TOTAUX",
        formatFCFA(totaux.brut),
        formatFCFA(totaux.cnpsSalarie),
        formatFCFA(totaux.cnpsPatronal),
        formatFCFA(totaux.its),
        formatFCFA(totaux.cn),
        formatFCFA(totaux.cmuSalarie + totaux.cmuPatronal),
        formatFCFA(totaux.net),
      ],
    ],
  };

  return { cnps, its, disa };
}

export async function buildPdf(
  opts: PdfOpts,
  mode: "save" | "blob" = "save",
): Promise<string | void> {
  const [{ default: jsPDF }, { default: autoTable }] = await Promise.all([
    import("jspdf"),
    import("jspdf-autotable"),
  ]);
  await ensurePdfLogo();
  await ensurePdfQr(opts.fileName.replace(/\.pdf$/, ""));
  const doc = new jsPDF({ orientation: "landscape" });
  const t = getActiveTemplate();
  const generatedAt = `Généré le ${new Date().toLocaleString("fr-FR")}`;

  autoTable(doc, {
    startY: getPdfChromeBodyTop(),
    head: opts.head,
    body: opts.body,
    foot: opts.foot,
    headStyles: PDF_TABLE.headStyles,
    footStyles: PDF_TABLE.footStyles,
    styles: { fontSize: PDF_TABLE.journalFontSize },
    columnStyles: Object.fromEntries(
      opts.head[0].slice(1).map((_, i) => [i + 1, { halign: "right" as const }]),
    ),
    margin: { ...PDF_MARGINS.journal, top: getPdfChromeBodyTop(), bottom: 52 },
    didDrawPage: () => {
      sharedDrawHeader(doc, opts.title, t);
      doc.setFontSize(9);
      doc.setFont("helvetica", "normal");
      doc.setTextColor(...PDF_COLORS.black);
      doc.text(opts.subtitle, 14, 36);
      doc.setFontSize(8);
      doc.setTextColor(...PDF_COLORS.muted);
      doc.text(generatedAt, doc.internal.pageSize.getWidth() - 14, 36, { align: "right" });
      sharedDrawFooter(doc, opts.footerText, t);
    },
  });
  sharedAddPageNumbers(doc);
  if (mode === "blob") {
    const url = doc.output("bloburl").toString();
    clearPdfQr();
    return url;
  }
  doc.save(opts.fileName);
  clearPdfQr();
}
