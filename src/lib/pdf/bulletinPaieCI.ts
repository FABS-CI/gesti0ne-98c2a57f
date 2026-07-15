// ---------------------------------------------------------------------------
// Bulletin de paie — conforme Côte d'Ivoire (modèle EDITIONS FABS)
// A4 portrait, sans en-tête/pied de page ERP. Tableau unifié 7 colonnes
// (N° · Désignation · Nbre · Base · Taux · Gains · Retenues) avec
// sous-totaux "SALAIRE BRUT IMPOSABLE" et "TOTAL RETENUES FISCALES &
// SOCIALES", puis rubriques non-imposables, cumuls annuels et mode de
// paiement. Les rubriques sont paramétrables : n'importe quel service RH
// ou comptable peut en ajouter via `lignes` (ou via `gains`/`retenues`
// pour compat).
// ---------------------------------------------------------------------------
import type jsPDFType from "jspdf";
import type autoTableType from "jspdf-autotable";
import logoUrl from "@/assets/fabs-logo.png";

export type BulletinLigne = {
  code?: string;
  libelle: string;
  nbre?: number | null;
  base?: number | null;
  taux?: number | null;
  gain?: number | null;
  retenue?: number | null;
  /** true = imposable (avant sous-total brut imposable), false = non-imposable
   *  (indemnités non-impo / autres retenues, après les sous-totaux). Défaut : true. */
  imposable?: boolean;
};

export type BulletinEntreprise = {
  raisonSociale: string;
  adresse?: string;
  telephone?: string;
  email?: string;
  rccm?: string;
  numContribuable?: string;
  cnpsEmployeur?: string;
};

export type BulletinSalarie = {
  matricule: string;
  nomComplet: string;
  fonction?: string;
  departement?: string;
  service?: string;
  categorie?: string;
  adresse?: string;
  parts?: number | string;
  dateEmbauche?: string;
  anciennete?: string;
  numCnps?: string;
};

export type BulletinPeriode = {
  periode: string; // libellé "Août 2022"
  mois?: string;
  annee?: string | number;
  du?: string;
  au?: string;
  dateEdition?: string;
};

export type BulletinTotaux = {
  totalGains: number;
  totalRetenues: number;
  salaireBrut: number;
  salaireImposable: number;
  netAPayer: number;
  totalIndemnitesNonImpo?: number;
  totalAutresRetenues?: number;
  coutSalarial?: number;
  coutEmployeur?: number;
};

export type BulletinPaiement = {
  date?: string;
  mode?: string;
};

export type BulletinCumulsAnnuels = {
  cr?: number;
  cn?: number;
  crn?: number;
  its?: number;
  igr?: number;
  brutImposable?: number;
  jrsTravailles?: number;
};

export type BulletinCIData = {
  reference: string;
  entreprise: BulletinEntreprise;
  salarie: BulletinSalarie;
  periode: BulletinPeriode;
  /** Rubriques du bulletin. À défaut, `gains`/`retenues` sont utilisés
   *  (compat, tous marqués imposables). Ajouter de nouvelles rubriques
   *  se fait simplement en poussant des éléments dans ce tableau. */
  lignes?: BulletinLigne[];
  gains?: Array<Omit<BulletinLigne, "gain" | "retenue"> & { montant: number }>;
  retenues?: Array<Omit<BulletinLigne, "gain" | "retenue"> & { montant: number }>;
  patronales?: BulletinLigne[];
  totaux: BulletinTotaux;
  paiement?: BulletinPaiement;
  cumuls?: BulletinCumulsAnnuels;
  observations?: string;
  /** Champs libres RH/Compta (références internes, notes, etc.). Rendus
   *  automatiquement dans un bloc dédié avant les signatures. */
  champsPersonnalises?: Array<{ label: string; valeur: string }>;
};

/** Options de mise en page A4 pour garantir un rendu homogène entre
 *  navigateurs / systèmes (marges physiques et taille de police de base). */
export type BulletinPdfOptions = {
  /** Marge en mm appliquée aux 4 côtés (par défaut 10 mm). */
  margin?: number;
  /** Taille de police du corps en pt (par défaut 8.5). Les tableaux et
   *  textes secondaires sont ajustés proportionnellement. */
  baseFontSize?: number;
};

// Entreprise par défaut (FABS-CI) — surchargée par l'appelant si besoin.
export const ENTREPRISE_FABS: BulletinEntreprise = {
  raisonSociale: "EDITIONS FABS-CI",
  adresse: "Bingerville, Qt N'GOTTO — BP 693",
  telephone: "+225 0759737123",
  email: "edition693fabs@gmail.com",
  rccm: "CI-ABJ-2020-B-12345",
  numContribuable: "2045123 A",
  cnpsEmployeur: "0123456",
};

// jsPDF/Helvetica ne contient pas U+202F/U+00A0 — on force une espace ASCII.
const stripNbsp = (s: string): string => s.replace(/[\u202F\u00A0]/g, " ");
const fmt = (n: number | null | undefined): string => {
  if (n === null || n === undefined || Number.isNaN(Number(n)) || Number(n) === 0) return "";
  return stripNbsp(new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 }).format(Number(n)));
};
const fmtAlways = (n: number | null | undefined): string => {
  if (n === null || n === undefined || Number.isNaN(Number(n))) return "0";
  return stripNbsp(new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 }).format(Number(n)));
};

const fmtTaux = (t: number | null | undefined): string => {
  if (t === null || t === undefined || Number.isNaN(Number(t)) || Number(t) === 0) return "";
  return stripNbsp(new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 2 }).format(Number(t)));
};

const fmtDate = (d?: string): string => {
  if (!d) return "";
  const dt = new Date(d);
  if (Number.isNaN(dt.getTime())) return d;
  return dt.toLocaleDateString("fr-FR", { day: "2-digit", month: "2-digit", year: "numeric" });
};

function lastY(doc: jsPDFType): number {
  return (doc as unknown as { lastAutoTable: { finalY: number } }).lastAutoTable.finalY;
}

// Charge le logo et le convertit en niveaux de gris pour un filigrane monochrome.
let cachedWatermark: string | null = null;
async function loadWatermarkDataUrl(): Promise<string | null> {
  if (cachedWatermark) return cachedWatermark;
  if (typeof window === "undefined" || typeof document === "undefined") return null;
  try {
    const res = await fetch(logoUrl);
    const blob = await res.blob();
    const bmp = await createImageBitmap(blob);
    const canvas = document.createElement("canvas");
    canvas.width = bmp.width;
    canvas.height = bmp.height;
    const ctx = canvas.getContext("2d");
    if (!ctx) return null;
    ctx.drawImage(bmp, 0, 0);
    const img = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const d = img.data;
    for (let i = 0; i < d.length; i += 4) {
      const g = Math.round(0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]);
      d[i] = d[i + 1] = d[i + 2] = g;
    }
    ctx.putImageData(img, 0, 0);
    cachedWatermark = canvas.toDataURL("image/png");
    return cachedWatermark;
  } catch {
    return null;
  }
}

function normaliseLignes(data: BulletinCIData): BulletinLigne[] {
  if (data.lignes && data.lignes.length) return data.lignes;
  const g = (data.gains ?? []).map<BulletinLigne>((l) => ({
    code: l.code,
    libelle: l.libelle,
    nbre: l.nbre,
    base: l.base,
    taux: l.taux,
    gain: l.montant,
    imposable: l.imposable ?? true,
  }));
  const r = (data.retenues ?? []).map<BulletinLigne>((l) => ({
    code: l.code,
    libelle: l.libelle,
    nbre: l.nbre,
    base: l.base,
    taux: l.taux,
    retenue: l.montant,
    imposable: l.imposable ?? true,
  }));
  return [...g, ...r];
}

export async function generateBulletinPaieCIPDF(
  data: BulletinCIData,
  opts: BulletinPdfOptions = {},
): Promise<Blob> {
  const [{ default: jsPDF }, { default: autoTable }] = (await Promise.all([
    import("jspdf"),
    import("jspdf-autotable"),
  ])) as unknown as [{ default: typeof jsPDFType }, { default: typeof autoTableType }];
  const doc = new jsPDF({ unit: "mm", format: "a4", orientation: "portrait" });
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const margin = Math.max(4, Math.min(30, opts.margin ?? 12));
  // Charte lisibilité RH — corps 9.5 pt, tableaux 9 pt (bien plus confortable
  // que l'ancienne base 8.5/8), en-têtes en gras plus visibles.
  const bfs = Math.max(7.5, Math.min(12, opts.baseFontSize ?? 9.5));
  const tfs = Math.max(7, bfs - 0.5);
  const ent = data.entreprise;
  // Charte 100 % noir & blanc (monochrome) — aucun coloris.
  // Palette 100 % monochrome, aucune zone remplie en noir.
  const NAVY: [number, number, number] = [0, 0, 0];
  const BORDER: [number, number, number] = [120, 120, 120];
  const SOFT: [number, number, number] = [250, 250, 250];
  const SUBTOTAL_BG: [number, number, number] = [240, 240, 240];
  const SUBTOTAL_RET_BG: [number, number, number] = [235, 235, 235];
  const ALT_ROW: [number, number, number] = [252, 252, 252];
  const SECTION_BG: [number, number, number] = [230, 230, 230];

  // --- En-tête sobre : fond blanc, texte noir, filet noir ---
  const bannerH = 24;
  doc.setTextColor(...NAVY);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(15);
  doc.text(ent.raisonSociale, margin, 10);
  doc.setFont("helvetica", "normal");
  doc.setFontSize(bfs - 0.5);
  const infoLine = [ent.adresse, ent.telephone ? `Tél. ${ent.telephone}` : null, ent.email]
    .filter(Boolean)
    .join("  ·  ");
  if (infoLine) doc.text(infoLine, margin, 15);
  const legalLine = [
    ent.rccm ? `RCCM ${ent.rccm}` : null,
    ent.numContribuable ? `NCC ${ent.numContribuable}` : null,
    ent.cnpsEmployeur ? `CNPS Employeur ${ent.cnpsEmployeur}` : null,
  ]
    .filter(Boolean)
    .join("  ·  ");
  if (legalLine) doc.text(legalLine, margin, 19.5);
  doc.setDrawColor(...NAVY);
  doc.setLineWidth(0.5);
  doc.line(margin, bannerH, pageW - margin, bannerH);

  // Titre du document
  doc.setTextColor(...NAVY);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(14);
  doc.text("BULLETIN DE PAIE", margin, bannerH + 7);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(bfs);
  const periodeLbl =
    data.periode.du && data.periode.au
      ? `Période : ${fmtDate(data.periode.du)} — ${fmtDate(data.periode.au)}`
      : `Période : ${data.periode.periode}`;
  doc.text(periodeLbl, pageW - margin, bannerH + 4, { align: "right" });
  doc.setFont("helvetica", "normal");
  doc.setFontSize(bfs - 1);
  const meta = [
    `Réf. : ${data.reference}`,
    data.periode.dateEdition ? `Édité le ${fmtDate(data.periode.dateEdition)}` : null,
  ]
    .filter(Boolean)
    .join("   ");
  doc.text(meta, pageW - margin, bannerH + 8.5, { align: "right" });
  doc.setDrawColor(...BORDER);
  doc.setLineWidth(0.3);
  doc.line(margin, bannerH + 11, pageW - margin, bannerH + 11);
  doc.setTextColor(30);

  // --- Carte "Salarié" ---
  const s = data.salarie;
  let y = bannerH + 14;
  const cardX = margin;
  const cardW = pageW - margin * 2;
  const salLines: Array<[string, string | undefined, string, string | undefined]> = [
    ["Matricule", s.matricule, "Fonction", s.fonction],
    ["N° CNPS", s.numCnps, "Catégorie", s.categorie],
    ["Département", s.departement, "Date d'embauche", fmtDate(s.dateEmbauche)],
    ["Adresse", s.adresse, "Parts", s.parts !== undefined ? String(s.parts) : undefined],
  ].filter(([, v1, , v2]) => v1 || v2) as typeof salLines;
  const cardH = 10 + salLines.length * 4.8 + 3;
  doc.setFillColor(...SOFT);
  doc.setDrawColor(...BORDER);
  doc.setLineWidth(0.3);
  doc.roundedRect(cardX, y, cardW, cardH, 1.5, 1.5, "FD");
  doc.setFont("helvetica", "bold");
  doc.setFontSize(11);
  doc.setTextColor(...NAVY);
  doc.text(s.nomComplet.toUpperCase(), cardX + 4, y + 6.5);
  doc.setDrawColor(...BORDER);
  doc.line(cardX + 4, y + 8.5, cardX + cardW - 4, y + 8.5);
  doc.setFontSize(bfs);
  doc.setTextColor(30);
  const col2X = cardX + cardW / 2 + 2;
  let ry = y + 13;
  for (const [k1, v1, k2, v2] of salLines) {
    if (v1) {
      doc.setFont("helvetica", "bold");
      doc.text(`${k1} :`, cardX + 4, ry);
      doc.setFont("helvetica", "normal");
      doc.text(String(v1), cardX + 4 + 28, ry);
    }
    if (v2) {
      doc.setFont("helvetica", "bold");
      doc.text(`${k2} :`, col2X, ry);
      doc.setFont("helvetica", "normal");
      doc.text(String(v2), col2X + 30, ry);
    }
    ry += 4.8;
  }
  y = y + cardH + 3;

  // --- Tableau unifié 7 colonnes avec sous-totaux ---
  const lignes = normaliseLignes(data);
  const impoGains = lignes.filter((l) => (l.gain ?? 0) > 0 && l.imposable !== false);
  const impoRetenues = lignes.filter((l) => (l.retenue ?? 0) > 0 && l.imposable !== false);
  const nonImpoGains = lignes.filter((l) => (l.gain ?? 0) > 0 && l.imposable === false);
  const nonImpoRetenues = lignes.filter((l) => (l.retenue ?? 0) > 0 && l.imposable === false);

  const sumGain = (arr: BulletinLigne[]) => arr.reduce((s, l) => s + (l.gain ?? 0), 0);
  const sumRet = (arr: BulletinLigne[]) => arr.reduce((s, l) => s + (l.retenue ?? 0), 0);

  const brutImposable = data.totaux.salaireImposable || sumGain(impoGains);
  const totalRetenuesFS = sumRet(impoRetenues);
  const totalIndNonImpo = data.totaux.totalIndemnitesNonImpo ?? sumGain(nonImpoGains);
  const totalAutresRet = data.totaux.totalAutresRetenues ?? sumRet(nonImpoRetenues);

  const rowFor = (l: BulletinLigne) => [
    l.code ?? "",
    l.libelle,
    l.nbre != null ? String(l.nbre) : "",
    fmt(l.base),
    fmtTaux(l.taux),
    fmt(l.gain ?? 0),
    fmt(l.retenue ?? 0),
  ];

  const body: (
    string | { content: string; colSpan?: number; styles?: Record<string, unknown> }
  )[][] = [];
  const sectionRow = (label: string) => [
    {
      content: label,
      colSpan: 7,
      styles: {
        fontStyle: "bold",
        halign: "left",
        fillColor: SECTION_BG,
        textColor: NAVY,
        cellPadding: 2,
      },
    },
  ];
  if (impoGains.length) body.push(sectionRow("GAINS IMPOSABLES"));
  for (const l of impoGains) body.push(rowFor(l));
  body.push([
    {
      content: "SALAIRE BRUT IMPOSABLE",
      colSpan: 5,
      styles: { fontStyle: "bold", halign: "right", fillColor: SUBTOTAL_BG },
    },
    {
      content: fmtAlways(brutImposable),
      styles: { fontStyle: "bold", fillColor: SUBTOTAL_BG },
    },
    { content: "", styles: { fillColor: SUBTOTAL_BG } },
  ]);
  if (impoRetenues.length)
    body.push(sectionRow("RETENUES FISCALES & SOCIALES (CNPS, ITS, IGR, CN…)"));
  for (const l of impoRetenues) body.push(rowFor(l));
  body.push([
    {
      content: "TOTAL RETENUES FISCALES & SOCIALES",
      colSpan: 6,
      styles: { fontStyle: "bold", halign: "right", fillColor: SUBTOTAL_RET_BG },
    },
    {
      content: fmtAlways(totalRetenuesFS),
      styles: { fontStyle: "bold", fillColor: SUBTOTAL_RET_BG },
    },
  ]);
  if (nonImpoGains.length) body.push(sectionRow("INDEMNITÉS NON IMPOSABLES"));
  for (const l of nonImpoGains) body.push(rowFor(l));
  if (nonImpoRetenues.length) body.push(sectionRow("AUTRES RETENUES"));
  for (const l of nonImpoRetenues) body.push(rowFor(l));

  autoTable(doc, {
    startY: y + 2,
    margin: { left: margin, right: margin },
    head: [["N°", "DÉSIGNATION", "NBRE.", "BASE", "TAUX", "GAINS", "RETENUES"]],
    body,
    styles: {
      fontSize: tfs,
      cellPadding: 2.4,
      lineColor: BORDER,
      lineWidth: 0.1,
      valign: "middle",
      overflow: "linebreak",
    },
    headStyles: {
      fillColor: SOFT,
      textColor: NAVY,
      fontStyle: "bold",
      fontSize: tfs + 0.5,
      halign: "center",
      cellPadding: 2.6,
      lineColor: NAVY,
      lineWidth: 0.2,
    },
    alternateRowStyles: { fillColor: ALT_ROW },
    columnStyles: {
      0: { cellWidth: 9, halign: "center" },
      1: { cellWidth: "auto", fontStyle: "bold" },
      2: { cellWidth: 11, halign: "right" },
      3: { cellWidth: 20, halign: "right" },
      4: { cellWidth: 13, halign: "right" },
      5: { cellWidth: 26, halign: "right" },
      6: { cellWidth: 26, halign: "right" },
    },
    theme: "grid",
  });
  y = lastY(doc);

  // --- Helper : bascule automatique en page suivante si besoin ---
  const bottomMargin = 16;
  const ensureSpace = (needed: number): void => {
    if (y + needed > pageH - bottomMargin) {
      doc.addPage();
      y = margin + 4;
      doc.setFont("helvetica", "italic");
      doc.setFontSize(8);
      doc.setTextColor(120);
      doc.text(
        `Bulletin de paie — ${data.salarie.nomComplet} — ${data.periode.periode} (suite)`,
        pageW / 2,
        y,
        { align: "center" },
      );
      y += 5;
      doc.setTextColor(30);
    }
  };

  // --- Synthèse 3 blocs : BRUT | RETENUES | NET À PAYER ---
  ensureSpace(28);
  const boxY = y + 4;
  const boxH = 20;
  const totalW = pageW - margin * 2;
  const gap = 3;
  const boxW = (totalW - gap * 2) / 3;
  const drawBox = (
    x: number,
    label: string,
    value: string,
    bg: [number, number, number],
    fg: [number, number, number],
    big = false,
  ) => {
    doc.setFillColor(...bg);
    doc.setDrawColor(...NAVY);
    doc.setLineWidth(0.4);
    doc.roundedRect(x, boxY, boxW, boxH, 2, 2, "FD");
    doc.setTextColor(...fg);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(9);
    doc.text(label, x + 4, boxY + 6.5);
    doc.setFontSize(big ? 16 : 13);
    doc.text(`${value} FCFA`, x + boxW - 4, boxY + 14.5, { align: "right" });
  };
  drawBox(
    margin,
    "SALAIRE BRUT",
    fmtAlways(data.totaux.salaireBrut || brutImposable),
    SUBTOTAL_BG,
    NAVY,
  );
  drawBox(
    margin + boxW + gap,
    "TOTAL RETENUES",
    fmtAlways(totalRetenuesFS + totalAutresRet),
    SUBTOTAL_RET_BG,
    NAVY,
  );
  drawBox(
    margin + (boxW + gap) * 2,
    "NET À PAYER",
    fmtAlways(data.totaux.netAPayer),
    [255, 255, 255],
    NAVY,
    true,
  );
  doc.setTextColor(30);
  y = boxY + boxH;

  // Ligne d'infos secondaires (indemnités non impo, coût employeur)
  if (totalIndNonImpo || totalAutresRet || data.totaux.coutSalarial || data.totaux.coutEmployeur) {
    y += 3;
    doc.setFont("helvetica", "bold");
    doc.setFontSize(bfs - 0.5);
    doc.setTextColor(80);
    const parts: string[] = [];
    if (totalIndNonImpo) parts.push(`Indemnités non imposables : ${fmtAlways(totalIndNonImpo)}`);
    if (data.totaux.coutSalarial ?? data.totaux.coutEmployeur)
      parts.push(
        `Coût employeur : ${fmtAlways(data.totaux.coutSalarial ?? data.totaux.coutEmployeur)}`,
      );
    if (parts.length) doc.text(parts.join("     ·     "), margin, y + 3);
    y += 5;
    doc.setTextColor(30);
  }

  // --- Cumuls annuels (optionnel) ---
  if (data.cumuls) {
    ensureSpace(24);
    const c = data.cumuls;
    autoTable(doc, {
      startY: y + 3,
      margin: { left: margin, right: margin },
      head: [
        [
          {
            content: "CUMULS ANNUELS",
            colSpan: 7,
            styles: { halign: "center", fillColor: SECTION_BG, textColor: NAVY, fontStyle: "bold" },
          },
        ],
        ["C.R", "C.N", "C.R.N", "I.T.S", "I.G.R", "BRUT IMPOSABLE", "JRS. TRAV."],
      ],
      body: [
        [
          fmtAlways(c.cr),
          fmtAlways(c.cn),
          fmtAlways(c.crn),
          fmtAlways(c.its),
          fmtAlways(c.igr),
          fmtAlways(c.brutImposable),
          fmtAlways(c.jrsTravailles),
        ],
      ],
      styles: { fontSize: tfs, halign: "right", cellPadding: 2.2, lineColor: BORDER },
      headStyles: {
        fillColor: SUBTOTAL_BG,
        textColor: NAVY,
        halign: "center",
        fontStyle: "bold",
      },
      theme: "grid",
      pageBreak: "auto",
      didDrawPage: () => {
        // autotable a lui-même géré le saut, on synchronise `y`
      },
    });
    y = lastY(doc);
  }

  // --- Champs personnalisés (RH / Compta) ---
  if (data.champsPersonnalises && data.champsPersonnalises.length > 0) {
    ensureSpace(8 + data.champsPersonnalises.length * 4);
    y += 4;
    doc.setFont("helvetica", "bold");
    doc.setFontSize(bfs);
    doc.setTextColor(...NAVY);
    doc.text("INFORMATIONS COMPLÉMENTAIRES", margin, y);
    y += 3;
    doc.setDrawColor(...BORDER);
    doc.line(margin, y, pageW - margin, y);
    y += 3;
    doc.setFont("helvetica", "normal");
    doc.setFontSize(tfs);
    doc.setTextColor(30);
    const colW = (pageW - margin * 2) / 2;
    let col = 0;
    let rowY = y;
    for (const c of data.champsPersonnalises) {
      ensureSpace(5);
      const x = margin + col * colW;
      doc.setFont("helvetica", "bold");
      doc.text(`${c.label} :`, x, rowY);
      doc.setFont("helvetica", "normal");
      const kw = doc.getTextWidth(`${c.label} : `);
      const lines = doc.splitTextToSize(c.valeur, colW - kw - 2);
      doc.text(lines, x + kw, rowY);
      col = col === 0 ? 1 : 0;
      if (col === 0) rowY += 4.4;
    }
    y = col === 0 ? rowY : rowY + 4.4;
  }

  // --- Paiement + observations ---
  ensureSpace(12);
  y += 6;
  doc.setTextColor(30);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(bfs);
  if (data.paiement?.date) {
    doc.text("Salaire payé le :", margin, y);
    doc.setFont("helvetica", "normal");
    doc.text(fmtDate(data.paiement.date), margin + 30, y);
  }
  if (data.paiement?.mode) {
    doc.setFont("helvetica", "bold");
    doc.text("Mode de paiement :", margin + 80, y);
    doc.setFont("helvetica", "normal");
    doc.text(data.paiement.mode, margin + 115, y);
  }

  if (data.observations) {
    const lines = doc.splitTextToSize(data.observations, pageW - margin * 2);
    ensureSpace(6 + lines.length * 4);
    y += 5;
    doc.setFont("helvetica", "bold");
    doc.text("Observations :", margin, y);
    doc.setFont("helvetica", "normal");
    doc.text(lines, margin, y + 4);
    y += 4 + lines.length * 4;
  }

  // --- Pagination + mention légale (sur chaque page) ---
  const pageCount = doc.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setDrawColor(...BORDER);
    doc.setLineWidth(0.3);
    doc.line(margin, pageH - 10, pageW - margin, pageH - 10);
    doc.setFont("helvetica", "italic");
    doc.setFontSize(7.5);
    doc.setTextColor(90);
    doc.text(
      "Pour vous aider à faire valoir vos droits, conservez ce bulletin de paie sans limitation de durée. — Bulletin établi conformément au Code du travail de Côte d'Ivoire.",
      pageW / 2,
      pageH - 6,
      { align: "center", maxWidth: pageW - margin * 2 - 30 },
    );
    doc.setFont("helvetica", "bold");
    doc.setFontSize(7.5);
    doc.setTextColor(...NAVY);
    doc.text(`Page ${i} / ${pageCount}`, pageW - margin, pageH - 6, { align: "right" });
  }

  // --- Filigrane logo (monochrome, discret) sur chaque page ---
  const watermark = await loadWatermarkDataUrl();
  if (watermark) {
    const pageCountWm = doc.getNumberOfPages();
    const wmW = Math.min(pageW, pageH) * 0.55;
    const wmH = wmW; // ratio préservé côté canvas source
    const wmX = (pageW - wmW) / 2;
    const wmY = (pageH - wmH) / 2;
    type GStateCtor = new (opts: { opacity: number }) => unknown;
    const jsp = doc as unknown as {
      GState?: GStateCtor;
      setGState?: (s: unknown) => void;
      addImage: (data: string, fmt: string, x: number, y: number, w: number, h: number) => void;
    };
    for (let i = 1; i <= pageCountWm; i++) {
      doc.setPage(i);
      if (jsp.GState && jsp.setGState) {
        jsp.setGState(new jsp.GState({ opacity: 0.08 }));
      }
      try {
        jsp.addImage(watermark, "PNG", wmX, wmY, wmW, wmH);
      } catch {
        /* ignore */
      }
      if (jsp.GState && jsp.setGState) {
        jsp.setGState(new jsp.GState({ opacity: 1 }));
      }
    }
  }

  return doc.output("blob");
}

export function bulletinFileName(ref: string, employeNom: string): string {
  const slug = employeNom
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .toUpperCase();
  const refSlug = ref.replace(/[^a-zA-Z0-9]+/g, "-");
  return `${refSlug}_${slug}.pdf`;
}
