import {
  PDFDocument,
  rgb,
  StandardFonts,
  type PDFPage,
  type PDFFont,
  type PDFImage,
  type RGB,
} from "pdf-lib";
import fabsLogoUrl from "@/assets/fabs-logo.png";
import { getActiveTemplateId } from "@/lib/pdf/pdfConfig";
import {
  getDocumentSettingsSync,
  getTemplateForType,
  type DocType as SettingsDocType,
} from "@/lib/document-settings-api";
import { shouldShowQr } from "@/lib/pdf/docTypeConfig";
import { generateUnifiedCommercialPDF, generateUnifiedStatementPDF, generateUnifiedAchatPDF } from "./unified-generator";

// Raccourcit une référence longue (ex. "BL-2026-0703-160245-7188" -> "BL-7188",
// "CLI-70c43f16-..." -> "CLI-70C43F16") pour une meilleure lisibilité dans les
// documents de vente.
function shortRef(s?: string | null): string {
  if (!s) return "";
  const str = String(s).trim();
  if (!str) return "";
  const parts = str.split(/[-_/]/).filter(Boolean);
  if (parts.length <= 2) return str.toUpperCase();
  const prefix = parts[0];
  const last = parts[parts.length - 1];
  return `${prefix}-${last}`.toUpperCase();
}

// ----------------------------------------------------------------------------
// Helpers couleur
// ----------------------------------------------------------------------------
function hex(h: string): RGB {
  const c = h.replace("#", "");
  return rgb(
    parseInt(c.slice(0, 2), 16) / 255,
    parseInt(c.slice(2, 4), 16) / 255,
    parseInt(c.slice(4, 6), 16) / 255,
  );
}

const FABS_COLORS = {
  texteTableau: rgb(1, 1, 1),
  separateur: hex("#9CA3AF"),
  rouge: hex("#DC2626"),
  orange: hex("#FF6200"),
  noir: rgb(0, 0, 0),
  gris: hex("#6B7280"),
  grisClair: hex("#F0F4F8"),
  grisLigne: hex("#D1D5DB"),
  bleuTitre: hex("#1F4E79"),
  enteteTableau: hex("#5B8DB8"),
};

// ----------------------------------------------------------------------------
// 8 thèmes (port de backend/pdf_generator.py THEMES)
// ----------------------------------------------------------------------------
type Theme = {
  id: string;
  primary: RGB; // ligne pied orange / accent
  accent: RGB;
  title: RGB; // couleur titre document droite + Total impayé (FCFA)
  tableHdrBg: RGB;
  tableHdrTxt: RGB;
};

const THEMES: Record<string, Theme> = {
  fabs_ci: {
    id: "fabs_ci",
    primary: hex("#1B2A57"), // Bleu officiel FABS pour la ligne pied
    accent: hex("#1B2A57"),
    title: hex("#1B2A57"), // Titre en bleu officiel
    tableHdrBg: hex("#1B2A57"),
    tableHdrTxt: rgb(1, 1, 1),
  },
  classique_professionnel: {
    id: "classique_professionnel",
    primary: hex("#FF6200"),
    accent: hex("#1F4E79"),
    title: hex("#1F4E79"),
    tableHdrBg: hex("#5B8DB8"),
    tableHdrTxt: rgb(1, 1, 1),
  },
  moderne_bleu: {
    id: "moderne_bleu",
    primary: hex("#2563EB"),
    accent: hex("#1E40AF"),
    title: hex("#1E40AF"),
    tableHdrBg: hex("#2563EB"),
    tableHdrTxt: rgb(1, 1, 1),
  },
  premium: {
    id: "premium",
    primary: hex("#B8860B"),
    accent: hex("#1A1A2E"),
    title: hex("#1A1A2E"),
    tableHdrBg: hex("#1A1A2E"),
    tableHdrTxt: hex("#B8860B"),
  },
  corporate_orange: {
    id: "corporate_orange",
    primary: hex("#EA580C"),
    accent: hex("#1C1917"),
    title: hex("#1C1917"),
    tableHdrBg: hex("#EA580C"),
    tableHdrTxt: rgb(1, 1, 1),
  },
  elegant_administratif: {
    id: "elegant_administratif",
    primary: hex("#475569"),
    accent: hex("#0F172A"),
    title: hex("#0F172A"),
    tableHdrBg: hex("#334155"),
    tableHdrTxt: rgb(1, 1, 1),
  },
  minimaliste_moderne: {
    id: "minimaliste_moderne",
    primary: hex("#6366F1"),
    accent: hex("#111827"),
    title: hex("#4F46E5"),
    tableHdrBg: hex("#6366F1"),
    tableHdrTxt: rgb(1, 1, 1),
  },
  premium_luxe: {
    id: "premium_luxe",
    primary: hex("#7C3AED"),
    accent: hex("#1E1B4B"),
    title: hex("#1E1B4B"),
    tableHdrBg: hex("#5B21B6"),
    tableHdrTxt: hex("#FDE68A"),
  },
  education_edition: {
    id: "education_edition",
    primary: hex("#059669"),
    accent: hex("#064E3B"),
    title: hex("#064E3B"),
    tableHdrBg: hex("#047857"),
    tableHdrTxt: rgb(1, 1, 1),
  },
  classique: { id: "classique_professionnel" } as unknown as Theme,
  moderne: { id: "moderne_bleu" } as unknown as Theme,
  corporate: { id: "corporate_orange" } as unknown as Theme,
  administratif: { id: "elegant_administratif" } as unknown as Theme,
};

function resolveTheme(docType?: SettingsDocType | null): Theme {
  const id =
    (docType ? getTemplateForType(docType) : getDocumentSettingsSync().selected_template) ||
    getActiveTemplateId() ||
    "fabs_ci";
  const t = THEMES[id];
  if (!t) return THEMES.fabs_ci;
  if (!("primary" in t) || !(t as Theme).primary)
    return THEMES[(t as { id: string }).id] ?? THEMES.fabs_ci;
  return t;
}

const FABS_INFO = {
  nom: "EDITIONS FABS-CI",
  slogan: "Une innovation pour une école de qualité",
  adresse: "BP 693",
  telephone: "+225 0759737123",
  email: "edition693fabs@gmail.com",
  siegeL1:
    "Siège social : Bingerville, Qt N'GOTTO, Immeuble cité Angan A. fils et petits-fils, Rez de chaussée. BP 693 TEL : 2122800995/",
  siegeL2: "+225 0759737123 E-MAIL : edition693fabs@gmail.com",
  siegeL3:
    "RCCM : CI-ABJ-2020-B-12345 · CC : 2045123 A · N° CNPS : 0123456 · Banques : CORIS BANK C116 01011 007630824101 34 · SGBCI CI008 01123012343259990 95.",
};

const PAGE = { w: 595, h: 842 };
const MARGIN = { x: 42, top: 102, bottom: 74 };
const CONTENT_W = PAGE.w - MARGIN.x * 2;
const BODY_BOTTOM_Y = MARGIN.bottom + 85;

export type DocLigne = {
  num?: number;
  code?: string;
  designation?: string;
  total?: number;
  pu?: number;
  classe?: string;
  cycle?: string;
  niveau?: string;
  matiere?: string;
  codeArticle?: string;
  reference?: string;
  unite?: string;
  qte?: number;
  qteCommandee?: number;
  qteLivree?: number;
  qteRetournee?: number;
  motif?: string;
  prixUnitaire?: number;
  montant?: number;
  remisePct?: number;
  remiseMontant?: number;
  tvaPct?: number;
};

export type DocBase = {
  id?: string;
  facture_id?: string;
  commande_id?: string;
  proforma_id?: string;
  bl_id?: string;
  br_id?: string;
  reference: string;
  date: string;
  clientNom?: string | null;
  clientTel?: string | null;
  representant?: string | null;
  representantTel?: string | null;
  codeClient?: string | null;
  adresseClient?: string | null;
  villeClient?: string | null;
  communeClient?: string | null;
  paysClient?: string | null;
  emailClient?: string | null;
  ncc?: string | null;
  rccm?: string | null;
  modePaiement?: string | null;
  lignes?: DocLigne[];
  totalVente?: number;
  remisePct?: number;
  remise?: number;
  remiseLigneTotal?: number;
  remiseGlobale?: number;
  remiseGlobalePct?: number;
  montantHT?: number;
  tvaPct?: number;
  tva?: number;
  totalTTC?: number;
  paye?: number;
  soldeDu?: number;
  livreurNom?: string | null;
  dateReceptionClient?: string | null;
  nomReceptionnaireClient?: string | null;
  statut?: DocStatut | null;
  notes?: string | null;
};

export type DocStatut = {
  label: string;
  color?: string;
};

type DocType = "FC" | "PF" | "BC" | "BL" | "BR" | "AV" | "RP" | "BP" | "SP" | "BA" | "BT";

const TITRES: Record<DocType, string> = {
  FC: "Facture Client",
  PF: "Facture Proforma",
  BC: "Bon de Commande",
  BL: "Bon de Livraison",
  BR: "Bon de Retour",
  AV: "Note de Crédit / Avoir",
  RP: "Reçu de Paiement",
  BP: "Bulletin de Paie",
  SP: "Bon de Remise de Spécimens",
  BA: "Bon de Réception",
  BT: "Bon de Transfert Inter-dépôts",
};

function fmtMontant(n: number | null | undefined): string {
  if (n == null || isNaN(Number(n))) return "0";
  return Math.round(Number(n))
    .toLocaleString("fr-FR", { maximumFractionDigits: 0 })
    .replace(/[\u00A0\u202F,]/g, " ");
}

function fmtDate(d: string | Date): string {
  const date = typeof d === "string" ? new Date(d) : d;
  if (isNaN(date.getTime())) return String(d);
  const j = String(date.getDate()).padStart(2, "0");
  const m = String(date.getMonth() + 1).padStart(2, "0");
  return `${j}/${m}/${date.getFullYear()}`;
}

function fmtHeure(d: string | Date): string {
  const date = typeof d === "string" ? new Date(d) : d;
  if (isNaN(date.getTime())) return "";
  const h = String(date.getHours()).padStart(2, "0");
  const m = String(date.getMinutes()).padStart(2, "0");
  return `${h}:${m}`;
}

function slug(s: string | null | undefined): string {
  return (s ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toUpperCase()
    .slice(0, 40);
}

export function fileNameFor(reference: string, who?: string | null): string {
  const safeRef = reference.replace(/\|/g, "_").replace(/[^A-Za-z0-9_]+/g, "_");
  const suffix = who ? `_${slug(who)}` : "";
  return `${safeRef}${suffix}.pdf`;
}

type Ctx = {
  doc: PDFDocument;
  page: PDFPage;
  font: PDFFont;
  bold: PDFFont;
  italic: PDFFont;
  boldItalic: PDFFont;
  theme: Theme;
  logoImg: PDFImage | null;
  title: string;
  reference: string;
  dateStr: string;
  heureStr: string;
  signatureLabel: string;
  showQr: boolean;
  showBarcode: boolean;
};

type TextOpts = { size?: number; bold?: boolean; color?: RGB; font?: PDFFont; italic?: boolean };

function sanitizeForWinAnsi(s: string): string {
  if (!s) return s;
  return s
    .replace(/\u2212/g, "-")
    .replace(/[\u2010-\u2015]/g, "-")
    .replace(/[\u2018\u2019\u201A\u2032]/g, "'")
    .replace(/[\u201C\u201D\u201E\u2033]/g, '"')
    .replace(/\u2026/g, "...")
    .replace(/[\u00A0\u202F\u2007\u2009]/g, " ")
    .replace(/\u20AC/g, "EUR");
}

function text(ctx: Ctx, s: string, x: number, y: number, opts: TextOpts = {}) {
  ctx.page.drawText(sanitizeForWinAnsi(s ?? ""), {
    x,
    y,
    size: opts.size ?? 9,
    font: opts.font ?? (opts.italic ? ctx.italic : opts.bold ? ctx.bold : ctx.font),
    color: opts.color ?? FABS_COLORS.noir,
  });
}

function textRight(ctx: Ctx, s: string, xRight: number, y: number, opts: TextOpts = {}) {
  const f = opts.font ?? (opts.italic ? ctx.italic : opts.bold ? ctx.bold : ctx.font);
  const safe = sanitizeForWinAnsi(s ?? "");
  const w = f.widthOfTextAtSize(safe, opts.size ?? 9);
  text(ctx, safe, xRight - w, y, opts);
}

function textCenter(ctx: Ctx, s: string, cx: number, y: number, opts: TextOpts = {}) {
  const f = opts.bold ? ctx.bold : opts.italic ? ctx.italic : ctx.font;
  const w = f.widthOfTextAtSize(s ?? "", opts.size ?? 9);
  text(ctx, s, cx - w / 2, y, opts);
}

function fitText(ctx: Ctx, s: string, maxW: number, opts: TextOpts = {}): string {
  const f = opts.bold ? ctx.bold : opts.italic ? ctx.italic : ctx.font;
  const size = opts.size ?? 9;
  if (!s) return "";
  if (f.widthOfTextAtSize(s, size) <= maxW) return s;
  const ell = "…";
  let lo = 0;
  let hi = s.length;
  while (lo < hi) {
    const mid = Math.ceil((lo + hi) / 2);
    if (f.widthOfTextAtSize(s.slice(0, mid) + ell, size) <= maxW) lo = mid;
    else hi = mid - 1;
  }
  return s.slice(0, lo) + ell;
}

function drawLogo(ctx: Ctx, x: number, yBottom: number, h: number) {
  if (ctx.logoImg) {
    const ratio = ctx.logoImg.width / ctx.logoImg.height;
    const w = Math.min(h * ratio, h * 1.6);
    ctx.page.drawImage(ctx.logoImg, { x, y: yBottom, width: w, height: h });
    return w;
  }
  return h;
}

function drawHeader(ctx: Ctx, titre: string): number {
  const top = PAGE.h - 24;
  const logoH = 48;
  const logoY = top - 72;
  const logoW = drawLogo(ctx, MARGIN.x, logoY, logoH);
  const tx = MARGIN.x + logoW + 11;

  text(ctx, FABS_INFO.nom, tx, top, { size: 11, bold: true });
  text(ctx, FABS_INFO.slogan, tx, top - 9, { size: 8, bold: true, color: FABS_COLORS.noir });
  text(ctx, `Adresse :  ${FABS_INFO.adresse}`, tx, top - 20, { size: 8.5 });
  text(ctx, `Phone : ${FABS_INFO.telephone}`, tx, top - 33, { size: 8.5 });
  text(ctx, `Email : ${FABS_INFO.email}`, tx, top - 46, { size: 8.5 });

  textRight(ctx, ctx.dateStr, PAGE.w - MARGIN.x, top, { size: 9 });
  textRight(ctx, fmtHeure(new Date()), PAGE.w - MARGIN.x, top - 14, { size: 9 });

  textRight(ctx, titre.toUpperCase(), PAGE.w - MARGIN.x, top - 46, {
    size: 22,
    bold: true,
    color: ctx.theme.title,
  });

  const sepY = PAGE.h - MARGIN.top + 1.5;
  ctx.page.drawLine({
    start: { x: MARGIN.x, y: sepY },
    end: { x: PAGE.w - MARGIN.x, y: sepY },
    thickness: 1.4,
    color: ctx.theme.primary,
  });
  return sepY - 6;
}

async function drawFooter(ctx: Ctx) {
  const lineTop = MARGIN.bottom - 3;
  const lineBot = lineTop - 35;

  ctx.page.drawLine({
    start: { x: MARGIN.x, y: lineTop },
    end: { x: PAGE.w - MARGIN.x, y: lineTop },
    thickness: 1.5,
    color: ctx.theme.primary,
  });
  const cx = PAGE.w / 2;
  textCenter(ctx, FABS_INFO.siegeL1, cx, lineTop - 11, { size: 6.5, color: FABS_COLORS.gris });
  textCenter(ctx, FABS_INFO.siegeL2, cx, lineTop - 21, { size: 6.5, color: FABS_COLORS.gris });
  textCenter(ctx, FABS_INFO.siegeL3, cx, lineTop - 31, { size: 6.5, color: FABS_COLORS.gris });
  ctx.page.drawLine({
    start: { x: MARGIN.x, y: lineBot },
    end: { x: PAGE.w - MARGIN.x, y: lineBot },
    thickness: 1.5,
    color: ctx.theme.primary,
  });

  const qrSize = 60;
  if (ctx.showQr) {
    const { default: QRCode } = await import("qrcode");
    const qrDataUrl = await QRCode.toDataURL(`FABS-CI | ${ctx.reference}`, {
      margin: 0,
      width: qrSize * 2,
    });
    const png = await ctx.doc.embedPng(qrDataUrl);
    ctx.page.drawImage(png, { x: MARGIN.x, y: lineTop + 7, width: qrSize, height: qrSize });
  }
}

export async function generateApprovisionnementPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedAchatPDF(data);
}

// Reste du fichier legacy (Optionnel selon usage réel)
// ...
