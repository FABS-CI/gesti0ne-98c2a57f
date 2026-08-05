// ============================================================================
// Templates PDF officiels EDITIONS FABS-CI — port TypeScript fidèle de
// backend/pdf_generator.py (ERP-FABS V10). En-tête + pied de page strictement
// conformes au modèle de référence : logo officiel `LOGO BLANC BON BON.png`,
// mappé sur `src/assets/logo_fabs.png.asset.json`, à gauche,
// société + adresse + slogan beside, date/heure + titre en couleur du thème
// à droite, ligne séparatrice grise. Pied = ligne orange haute, 3 lignes
// siège centrées en gris, ligne orange basse, QR JSON bas-gauche, signature
// italique bas-droite. 8 thèmes sélectionnables via pdfConfig.
// ============================================================================

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
import { generateUnifiedCommercialPDF, generateUnifiedStatementPDF } from "./unified-generator";

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
    primary: hex("#F57C00"),
    accent: hex("#F57C00"),
    title: hex("#424242"),
    tableHdrBg: hex("#F57C00"),
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
  // alias modèles intégrés pdfConfig
  classique: { id: "classique_professionnel" } as unknown as Theme,
  moderne: { id: "moderne_bleu" } as unknown as Theme,
  corporate: { id: "corporate_orange" } as unknown as Theme,
  administratif: { id: "elegant_administratif" } as unknown as Theme,
};

function resolveTheme(docType?: SettingsDocType | null): Theme {
  // Priorité : template_per_type (DB) → selected_template (DB / cache) → fallback local
  const id =
    (docType ? getTemplateForType(docType) : getDocumentSettingsSync().selected_template) ||
    getActiveTemplateId() ||
    "fabs_ci";
  const t = THEMES[id];
  if (!t) return THEMES.fabs_ci;
  // résolution des alias (clé vers une autre clé)
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

// Mise en page A4 portrait (V10 : MT=3.6cm, MB=2.6cm)
const PAGE = { w: 595, h: 842 };
const MARGIN = { x: 42, top: 102, bottom: 74 };
const CONTENT_W = PAGE.w - MARGIN.x * 2;
const BODY_BOTTOM_Y = MARGIN.bottom + 85;

// ----------------------------------------------------------------------------
// Types
// ----------------------------------------------------------------------------
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
  /** Désignation complète du produit (utilisée par certains templates non commerciaux). */
  designation?: string;
  /** Unité de mesure (pièce, carton, kg…). */
  unite?: string;
  qte?: number;
  qteCommandee?: number;
  qteLivree?: number;
  qteRetournee?: number;
  motif?: string;
  prixUnitaire?: number;
  montant?: number;
  /** Remise appliquée à la ligne — pourcentage. */
  remisePct?: number;
  /** Remise appliquée à la ligne — montant FCFA. */
  remiseMontant?: number;
  /** Taux de TVA appliqué à la ligne (pourcentage). */
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
  /** Code (référence) du client — ex. CLI-000123 */
  codeClient?: string | null;
  /** Adresse postale */
  adresseClient?: string | null;
  /** Ville */
  villeClient?: string | null;
  /** Commune / quartier */
  communeClient?: string | null;
  /** Pays */
  paysClient?: string | null;
  /** Adresse e-mail */
  emailClient?: string | null;
  /** Numéro Compte Contribuable (NCC / NIF) */
  ncc?: string | null;
  /** Registre du Commerce (RCCM) */
  rccm?: string | null;
  modePaiement?: string | null;
  lignes?: DocLigne[];
  totalVente?: number;
  remisePct?: number;
  remise?: number;
  /** Cumul des remises appliquées ligne par ligne (FCFA). */
  remiseLigneTotal?: number;
  /** Remise globale appliquée après le tableau (FCFA). */
  remiseGlobale?: number;
  /** Pourcentage de la remise globale (calculé/affiché). */
  remiseGlobalePct?: number;
  montantHT?: number;
  tvaPct?: number;
  tva?: number;
  totalTTC?: number;
  paye?: number;
  soldeDu?: number;
  /** Informations de livraison pour le BL */
  livreurNom?: string | null;
  dateReceptionClient?: string | null;
  nomReceptionnaireClient?: string | null;
  /** Statut du document (Payée, Impayée, Annulée, Brouillon…). */
  statut?: DocStatut | null;
};

/** Statut affiché en en-tête du document (badge coloré + tampon). */
export type DocStatut = {
  label: string;
  /** Couleur hex (#RRGGBB). Par défaut gris. */
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

// ----------------------------------------------------------------------------
// Helpers de formatage
// ----------------------------------------------------------------------------
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

function slug(s: string | null | undefined): string {
  return (s ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toUpperCase()
    .slice(0, 40);
}

/** Nom de fichier intelligent : FABS_FC_26_15_LM-ABENGOUROU.pdf */
export function fileNameFor(reference: string, who?: string | null): string {
  const safeRef = reference.replace(/\|/g, "_").replace(/[^A-Za-z0-9_]+/g, "_");
  const suffix = who ? `_${slug(who)}` : "";
  return `${safeRef}${suffix}.pdf`;
}

// ----------------------------------------------------------------------------
// Contexte de dessin
// ----------------------------------------------------------------------------
type Ctx = {
  doc: PDFDocument;
  page: PDFPage;
  font: PDFFont;
  bold: PDFFont;
  italic: PDFFont;
  boldItalic: PDFFont;
  theme: Theme;
  logoImg: PDFImage | null;
  // Métadonnées dessinées dans le pied de chaque page
  title: string;
  reference: string;
  dateStr: string;
  heureStr: string;
  signatureLabel: string;
  showQr: boolean;
  showBarcode: boolean;
};

type TextOpts = { size?: number; bold?: boolean; color?: RGB; font?: PDFFont; italic?: boolean };

/**
 * pdf-lib's Standard fonts (Helvetica…) use the WinAnsi encoding and throw on
 * characters outside CP1252 (ex : le vrai signe moins U+2212 renvoyé par
 * Number.toLocaleString("fr-FR") pour les négatifs, les espaces fines U+202F,
 * les guillemets typographiques, l'ellipse U+2026, etc.).
 * On normalise systématiquement avant chaque drawText pour ne plus jamais
 * casser la génération d'un PDF à cause d'un caractère Unicode isolé.
 */
function sanitizeForWinAnsi(s: string): string {
  if (!s) return s;
  return s
    .replace(/\u2212/g, "-") // MINUS SIGN → hyphen-minus
    .replace(/[\u2010-\u2015]/g, "-") // various dashes → hyphen-minus
    .replace(/[\u2018\u2019\u201A\u2032]/g, "'") // curly single quotes
    .replace(/[\u201C\u201D\u201E\u2033]/g, '"') // curly double quotes
    .replace(/\u2026/g, "...") // ellipsis
    .replace(/[\u00A0\u202F\u2007\u2009]/g, " ") // NBSP / narrow NBSP / thin sp
    .replace(/\u20AC/g, "EUR"); // € (au cas où — WinAnsi le supporte mais on reste safe)
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

function textCenter(
  ctx: Ctx,
  s: string,
  cx: number,
  y: number,
  opts: TextOpts = {},
) {
  const f = opts.bold ? ctx.bold : opts.italic ? ctx.italic : ctx.font;
  const w = f.widthOfTextAtSize(s ?? "", opts.size ?? 9);
  text(ctx, s, cx - w / 2, y, opts);
}

/** Tronque une chaîne pour tenir dans maxW pt (ajoute "…" si coupé). */
function fitText(
  ctx: Ctx,
  s: string,
  maxW: number,
  opts: TextOpts = {},
): string {
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

function hline(ctx: Ctx, y: number, color: RGB = FABS_COLORS.separateur) {
  ctx.page.drawLine({
    start: { x: MARGIN.x, y },
    end: { x: PAGE.w - MARGIN.x, y },
    thickness: 0.8,
    color,
  });
}

// ----------------------------------------------------------------------------
// Logo officiel EDITIONS FABS-CI (LOGO BLANC BON BON.png via asset CDN).
// Aucun ancien logo/fallback résiduel n'est dessiné.
// ----------------------------------------------------------------------------
function drawLogo(ctx: Ctx, x: number, yBottom: number, h: number) {
  if (ctx.logoImg) {
    const ratio = ctx.logoImg.width / ctx.logoImg.height;
    const w = Math.min(h * ratio, h * 1.6);
    ctx.page.drawImage(ctx.logoImg, { x, y: yBottom, width: w, height: h });
    return w;
  }
  return h;
}

// ----------------------------------------------------------------------------
// En-tête commun — port strict du V10 _draw_header.
// ----------------------------------------------------------------------------
function drawHeader(ctx: Ctx, titre: string): number {
  const top = PAGE.h - 24; // TOP_Y ≈ h - 0.85cm
  const logoH = 48; // ≈ 1.7cm
  const logoY = top - 72; // ≈ h - 2.55cm
  const logoW = drawLogo(ctx, MARGIN.x, logoY, logoH);
  const tx = MARGIN.x + logoW + 11;

  // Société (gras noir) + slogan italique gris + adresse/phone/email noir
  text(ctx, FABS_INFO.nom, tx, top, { size: 11, bold: true });
  text(ctx, FABS_INFO.slogan, tx, top - 9, { size: 8, color: hex("#555555") });
  text(ctx, `Adresse :  ${FABS_INFO.adresse}`, tx, top - 20, { size: 8.5 });
  text(ctx, `Phone : ${FABS_INFO.telephone}`, tx, top - 33, { size: 8.5 });
  text(ctx, `Email : ${FABS_INFO.email}`, tx, top - 46, { size: 8.5 });

  // Date + Heure (droite, noir) + titre couleur thème, gras
  textRight(ctx, ctx.dateStr, PAGE.w - MARGIN.x, top, { size: 9 });
  textRight(ctx, ctx.heureStr, PAGE.w - MARGIN.x, top - 14, { size: 9 });
  textRight(ctx, titre.toUpperCase(), PAGE.w - MARGIN.x, top - 46, {
    size: 22,
    bold: true,
    color: ctx.theme.title,
  });

  // Ligne séparatrice thème (orange FABS-CI) sous l'en-tête, style référence
  const sepY = PAGE.h - MARGIN.top + 1.5;
  ctx.page.drawLine({
    start: { x: MARGIN.x, y: sepY },
    end: { x: PAGE.w - MARGIN.x, y: sepY },
    thickness: 1.4,
    color: ctx.theme.primary,
  });
  return sepY - 6;
}

// ----------------------------------------------------------------------------
// Pied de page commun — port strict du V10 _draw_footer.
// Ligne orange haute, 3 lignes siège centrées gris, ligne orange basse,
// QR JSON bas-gauche, signature italique couleur thème bas-droite.
// ----------------------------------------------------------------------------
async function drawFooter(ctx: Ctx) {
  const lineTop = MARGIN.bottom - 3;
  const lineBot = lineTop - 35;

  // Ligne orange haute (couleur primary thème)
  ctx.page.drawLine({
    start: { x: MARGIN.x, y: lineTop },
    end: { x: PAGE.w - MARGIN.x, y: lineTop },
    thickness: 1.5,
    color: ctx.theme.primary,
  });
  // 3 lignes siège centrées petit gris
  const cx = PAGE.w / 2;
  textCenter(ctx, FABS_INFO.siegeL1, cx, lineTop - 11, { size: 6.5, color: FABS_COLORS.gris });
  textCenter(ctx, FABS_INFO.siegeL2, cx, lineTop - 21, { size: 6.5, color: FABS_COLORS.gris });
  textCenter(ctx, FABS_INFO.siegeL3, cx, lineTop - 31, { size: 6.5, color: FABS_COLORS.gris });
  // Ligne orange basse
  ctx.page.drawLine({
    start: { x: MARGIN.x, y: lineBot },
    end: { x: PAGE.w - MARGIN.x, y: lineBot },
    thickness: 1.5,
    color: ctx.theme.primary,
  });

  // QR code au-dessus de la ligne haute (bas-gauche)
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
  // Code-barres retiré des documents de vente (demande produit).

  // ----------------------------------------------------------------------------
  // 12. Bon de Livraison (BL) — avec zones de signature
  // ----------------------------------------------------------------------------
  if (ctx.title === "Bon de Livraison" || ctx.title.toUpperCase() === "BON DE LIVRAISON") {
    const ySign = lineTop + 9;
    const boxW = (CONTENT_W - 20) / 2;
    const boxH = 50;

    // Bloc 1 : Réception Client
    ctx.page.drawRectangle({
      x: MARGIN.x,
      y: ySign,
      width: boxW,
      height: boxH,
      borderWidth: 0.5,
      borderColor: FABS_COLORS.grisLigne,
    });
    text(ctx, "RÉCEPTION CLIENT", MARGIN.x + 5, ySign + boxH - 12, { size: 8, bold: true });
    text(ctx, "Nom : ....................................", MARGIN.x + 5, ySign + boxH - 25, { size: 8 });
    text(ctx, "Date : .... / .... / 2026", MARGIN.x + 5, ySign + boxH - 38, { size: 8 });
    text(ctx, "Signature & Cachet :", MARGIN.x + 5, ySign + boxH - 48, { size: 7, italic: true, font: ctx.italic });

    // Bloc 2 : Livraison effectuée par
    ctx.page.drawRectangle({
      x: PAGE.w - MARGIN.x - boxW,
      y: ySign,
      width: boxW,
      height: boxH,
      borderWidth: 0.5,
      borderColor: FABS_COLORS.grisLigne,
    });
    text(ctx, "LIVRAISON EFFECTUÉE PAR", PAGE.w - MARGIN.x - boxW + 5, ySign + boxH - 12, { size: 8, bold: true });
    text(ctx, "Nom : ....................................", PAGE.w - MARGIN.x - boxW + 5, ySign + boxH - 25, { size: 8 });
    text(ctx, `Date : ${ctx.dateStr}`, PAGE.w - MARGIN.x - boxW + 5, ySign + boxH - 38, { size: 8 });
    text(ctx, "Signature Livreur :", PAGE.w - MARGIN.x - boxW + 5, ySign + boxH - 48, { size: 7, italic: true, font: ctx.italic });

    return;
  }

  // Signature droite italique gras couleur accent
  textRight(ctx, ctx.signatureLabel, PAGE.w - MARGIN.x, lineTop + 9, {
    size: 9,
    font: ctx.boldItalic,
    color: ctx.theme.accent,
  });
}

// ----------------------------------------------------------------------------
// Bloc informations transaction (2 colonnes)
// ----------------------------------------------------------------------------
function drawInfosTransaction(
  ctx: Ctx,
  data: DocBase,
  yStart: number,
  partyLabel: string = "CLIENT",
): number {
  const colR = MARGIN.x + CONTENT_W / 2;

  // Colonne gauche : bloc CLIENT complet
  let yL = yStart;
  text(ctx, partyLabel, MARGIN.x, yL, {
    size: 10,
    bold: true,
    color: ctx.theme.primary,
  });
  yL -= 14;
  if (data.clientNom) {
    text(ctx, data.clientNom, MARGIN.x, yL, { size: 13, bold: true });
    yL -= 14;
  }
  const kv = (label: string, value?: string | null) => {
    if (!value) return;
    text(ctx, `${label} : ${value}`, MARGIN.x, yL, { size: 11 });
    yL -= 13;
  };
  kv("Code", shortRef(data.codeClient));
  kv("Représentant", data.representant);
  kv("Téléphone", data.representantTel ?? data.clientTel);
  kv("Email", data.emailClient);
  kv("Adresse", data.adresseClient);
  const villeLine = [data.communeClient, data.villeClient, data.paysClient]
    .filter(Boolean)
    .join(", ");
  if (villeLine) kv("Ville", villeLine);
  kv("NCC", data.ncc);
  kv("RCCM", data.rccm);

  // Colonne droite : infos document
  let yR = yStart;
  text(ctx, "DOCUMENT", colR, yR, {
    size: 10,
    bold: true,
    color: ctx.theme.primary,
  });
  yR -= 14;
  text(ctx, `Réf.  : ${shortRef(data.reference)}`, colR, yR, { size: 11, bold: true });
  yR -= 13;
  text(ctx, `Date  : ${fmtDate(data.date)}`, colR, yR, { size: 11 });
  yR -= 13;
  if (data.modePaiement) {
    text(ctx, `Mode  : ${data.modePaiement}`, colR, yR, { size: 11 });
    yR -= 13;
  }
  if (data.statut && data.statut.label) {
    const col = data.statut.color ? hex(data.statut.color) : FABS_COLORS.gris;
    const label = `Statut : ${data.statut.label.toUpperCase()}`;
    const w = ctx.bold.widthOfTextAtSize(label, 10) + 12;
    ctx.page.drawRectangle({
      x: colR - 2,
      y: yR - 3,
      width: w,
      height: 15,
      borderColor: col,
      borderWidth: 1.2,
      color: col,
      opacity: 0.12,
      borderOpacity: 1,
    });
    text(ctx, label, colR + 4, yR + 1, { size: 10, bold: true, color: col });
    yR -= 18;
  }

  const yEnd = Math.min(yL, yR) - 4;
  hline(ctx, yEnd);
  return yEnd - 8;
}

// ----------------------------------------------------------------------------
// Tableau des lignes (colonnes configurables)
// ----------------------------------------------------------------------------
type Colonne = {
  key: keyof DocLigne;
  label: string;
  width: number; // proportion
  align: "left" | "center" | "right";
  money?: boolean;
  /** Affiche la valeur sous forme "X %". */
  percent?: boolean;
  /** Autorise le retour à la ligne (row height dynamique). */
  wrap?: boolean;
};

/** Découpe une chaîne en lignes tenant chacune dans maxW pt. */
function wrapText(
  ctx: Ctx,
  s: string,
  maxW: number,
  opts: { size?: number; bold?: boolean } = {},
): string[] {
  const f = opts.bold ? ctx.bold : ctx.font;
  const size = opts.size ?? 9;
  if (!s) return [""];
  const words = String(s).split(/\s+/);
  const lines: string[] = [];
  let cur = "";
  const fits = (t: string) => f.widthOfTextAtSize(t, size) <= maxW;
  const pushLongWord = (w: string) => {
    let rest = w;
    while (rest && !fits(rest)) {
      let lo = 1;
      let hi = rest.length;
      while (lo < hi) {
        const mid = Math.ceil((lo + hi) / 2);
        if (fits(rest.slice(0, mid))) lo = mid;
        else hi = mid - 1;
      }
      lines.push(rest.slice(0, lo));
      rest = rest.slice(lo);
    }
    cur = rest;
  };
  for (const w of words) {
    if (!w) continue;
    const tentative = cur ? `${cur} ${w}` : w;
    if (fits(tentative)) {
      cur = tentative;
    } else if (!cur) {
      pushLongWord(w);
    } else {
      lines.push(cur);
      if (fits(w)) cur = w;
      else pushLongWord(w);
    }
  }
  if (cur) lines.push(cur);
  return lines.length ? lines : [""];
}

async function drawTableau(
  ctx: Ctx,
  titre: string,
  colonnes: Colonne[],
  lignes: DocLigne[],
  yStart: number,
  groupByCycle = true,
): Promise<number> {
  const totalW = colonnes.reduce((a, c) => a + c.width, 0);
  const colX: number[] = [];
  let acc = MARGIN.x;
  for (const c of colonnes) {
    colX.push(acc);
    acc += (c.width / totalW) * CONTENT_W;
  }
  const rowH = 16;
  const hasMontant = colonnes.some((c) => c.key === "montant");

  const drawHeaderRow = (yTop: number) => {
    ctx.page.drawRectangle({
      x: MARGIN.x,
      y: yTop - rowH,
      width: CONTENT_W,
      height: rowH,
      color: ctx.theme.primary,
    });
    colonnes.forEach((c, i) => {
      const x0 = colX[i];
      const x1 = (colX[i + 1] ?? MARGIN.x + CONTENT_W) - 4;
      const ty = yTop - rowH + 5;
      const maxW = Math.max(4, x1 - x0 - 2);
      const label = fitText(ctx, c.label, maxW, { size: 8, bold: true });
      if (c.align === "right")
        textRight(ctx, label, x1, ty, { size: 8, bold: true, color: FABS_COLORS.texteTableau });
      else if (c.align === "center")
        textCenter(ctx, label, (x0 + x1) / 2, ty, {
          size: 8,
          bold: true,
          color: FABS_COLORS.texteTableau,
        });
      else text(ctx, label, x0 + 3, ty, { size: 8, bold: true, color: FABS_COLORS.texteTableau });
    });
    return yTop - rowH;
  };

  // Regroupement V10 par cycle scolaire
  const seen: string[] = [];
  const groups: Record<string, DocLigne[]> = {};
  for (const l of lignes) {
    const c = (l.cycle ?? "").toString().toUpperCase();
    if (!(c in groups)) {
      seen.push(c);
      groups[c] = [];
    }
    groups[c].push(l);
  }
  const hasCycle = seen.some((c) => c !== "");
  const groupCycle = groupByCycle && hasCycle;

  let pageTop = yStart;
  let y = drawHeaderRow(pageTop);
  let rowIdx = 0;

  const drawPageBorder = () => {
    ctx.page.drawRectangle({
      x: MARGIN.x,
      y,
      width: CONTENT_W,
      height: pageTop - y,
      borderColor: FABS_COLORS.separateur,
      borderWidth: 0.6,
    });
  };

  const continueTable = async () => {
    drawPageBorder();
    await drawFooter(ctx);
    ctx.page = ctx.doc.addPage([PAGE.w, PAGE.h]);
    pageTop = drawHeader(ctx, `${titre} (suite)`) - 12;
    y = drawHeaderRow(pageTop);
    rowIdx = 0;
  };

  const ensureRowsFit = async (rowsNeeded = 1) => {
    if (y - rowH * rowsNeeded < BODY_BOTTOM_Y) {
      await continueTable();
    }
  };

  for (const cycleName of seen) {
    const items = groups[cycleName];

    if (groupCycle && cycleName) {
      await ensureRowsFit(items.length > 0 ? 2 : 1);
      y -= rowH;
      ctx.page.drawRectangle({
        x: MARGIN.x,
        y,
        width: CONTENT_W,
        height: rowH,
        color: hex("#EEF2F7"),
      });
      text(ctx, cycleName, MARGIN.x + 6, y + 5, { size: 9, bold: true, color: ctx.theme.title });
    }

    let subtotal = 0;
    for (const ligne of items) {
      // Pré-calcule les cellules pour dimensionner la hauteur de ligne
      const cells = colonnes.map((c, i) => {
        const x0 = colX[i];
        const x1 = (colX[i + 1] ?? MARGIN.x + CONTENT_W) - 4;
        let raw = ligne[c.key];
        if ((raw == null || raw === "") && c.key === "qteCommandee") raw = ligne.qte;
        if ((raw == null || raw === "") && c.key === "qteLivree")
          raw = ligne.qteCommandee ?? ligne.qte;
        if ((raw == null || raw === "") && c.key === "niveau") raw = ligne.cycle;
        let s: string;
        if (raw == null || raw === "") s = "";
        else if (c.percent) s = `${Number(raw)} %`;
        else if (c.money) s = fmtMontant(Number(raw));
        else s = String(raw);
        const maxW = Math.max(4, x1 - x0 - 2);
        const lines = c.wrap
          ? wrapText(ctx, s, maxW, { size: 8 })
          : [fitText(ctx, s, maxW, { size: 8 })];
        return { c, x0, x1, maxW, lines };
      });
      const lineH = 10;
      const maxLines = Math.max(1, ...cells.map((c) => c.lines.length));
      const thisRowH = Math.max(rowH, maxLines * lineH + 4);
      if (y - thisRowH < BODY_BOTTOM_Y) await continueTable();
      y -= thisRowH;
      if (rowIdx % 2 === 1) {
        ctx.page.drawRectangle({
          x: MARGIN.x,
          y,
          width: CONTENT_W,
          height: thisRowH,
          color: FABS_COLORS.grisClair,
        });
      }
      rowIdx += 1;
      cells.forEach(({ c, x0, x1, lines }) => {
        lines.forEach((shown, li) => {
          const ty = y + thisRowH - 10 - li * lineH;
          if (c.align === "right") textRight(ctx, shown, x1, ty, { size: 8 });
          else if (c.align === "center") textCenter(ctx, shown, (x0 + x1) / 2, ty, { size: 8 });
          else text(ctx, shown, x0 + 3, ty, { size: 8 });
        });
      });
      subtotal += Number(ligne.montant ?? 0);
    }

    if (groupCycle && cycleName && hasMontant) {
      await ensureRowsFit();
      y -= rowH;
      ctx.page.drawRectangle({
        x: MARGIN.x,
        y,
        width: CONTENT_W,
        height: rowH,
        color: hex("#EEF2F7"),
      });
      text(ctx, `Sous-total ${cycleName}`, colX[0] + 6, y + 5, { size: 8, bold: true });
      textRight(ctx, fmtMontant(subtotal), MARGIN.x + CONTENT_W - 4, y + 5, {
        size: 8,
        bold: true,
      });
    }
  }

  if (!groupCycle && hasMontant) {
    await ensureRowsFit();
    const total = lignes.reduce((a, l) => a + Number(l.montant ?? 0), 0);
    y -= rowH;
    ctx.page.drawRectangle({
      x: MARGIN.x,
      y,
      width: CONTENT_W,
      height: rowH,
      color: FABS_COLORS.grisClair,
    });
    text(ctx, "Sous-total articles", colX[0] + 3, y + 5, { size: 8, bold: true });
    textRight(ctx, fmtMontant(total), MARGIN.x + CONTENT_W - 4, y + 5, { size: 8, bold: true });
  }

  drawPageBorder();
  return y - 12;
}

async function addContinuationPage(ctx: Ctx, titre: string): Promise<number> {
  await drawFooter(ctx);
  ctx.page = ctx.doc.addPage([PAGE.w, PAGE.h]);
  return drawHeader(ctx, `${titre} (suite)`) - 12;
}

// ============================================================================
// Nouveau template inspiré du modèle de référence "bleu" — décliné en orange
// FABS-CI. Utilisé pour les 5 documents de vente : FC / PF / BC / BL / RP.
//   • Bloc infos client 2 colonnes avec Référence/Date/Ville/Client/Rep.
//   • Tableau regroupé par cycle avec en-tête répété par groupe et
//     sous-total aligné à droite dans la colonne Montant.
//   • Bloc totaux : 4 cartes horizontales (Montant, Remise %, Remise, HT)
//     et QR code à gauche.
// ============================================================================

function drawSalesInfos(ctx: Ctx, data: DocBase, yStart: number): number {
  const colR = MARGIN.x + CONTENT_W / 2;
  let yL = yStart;
  let yR = yStart;

  // Ligne 1 : Référence (gauche) + Date (droite)
  text(ctx, "Référence :", MARGIN.x, yL, { size: 10, bold: true });
  text(ctx, shortRef(data.reference), MARGIN.x + 80, yL, {
    size: 11,
    bold: true,
    color: ctx.theme.primary,
  });
  text(ctx, "Date :", colR, yR, { size: 10, bold: true });
  text(ctx, fmtDate(data.date), colR + 80, yR, { size: 11, bold: true });
  yL -= 18;
  yR -= 18;

  // Ligne 2 : Ville en gras (gauche)
  const ville = [data.communeClient, data.villeClient].filter(Boolean).join(", ");
  if (ville) {
    text(ctx, ville.toUpperCase(), MARGIN.x, yL, { size: 11, bold: true });
  }
  yL -= 16;

  // Ligne 3 : Nom client (gauche) + Représentant (droite)
  if (data.clientNom) {
    text(ctx, data.clientNom, MARGIN.x, yL, { size: 11, bold: true });
    yL -= 16;
  }
  if (data.representant) {
    text(ctx, "Représentant :", colR, yR, { size: 10, bold: true });
    text(ctx, data.representant, colR + 95, yR, { size: 11, bold: true });
    yR -= 16;
  }

  // Ligne 4 : Type client (gauche) + Phone repre. (droite)
  const typeCli =
    (data as unknown as { typeClient?: string | null }).typeClient ?? null;
  if (typeCli) {
    text(ctx, "Type Client :", MARGIN.x, yL, { size: 10, bold: true });
    text(ctx, typeCli.toUpperCase(), MARGIN.x + 90, yL, { size: 11, bold: true });
    yL -= 16;
  }
  const tel = data.representantTel ?? data.clientTel;
  if (tel) {
    text(ctx, "Phone Repre. :", colR, yR, { size: 10, bold: true });
    text(ctx, tel, colR + 95, yR, { size: 11, bold: true });
    yR -= 16;
  }

  // Statut : badge coloré (optionnel)
  if (data.statut && data.statut.label) {
    const col = data.statut.color ? hex(data.statut.color) : FABS_COLORS.gris;
    const label = `Statut : ${data.statut.label.toUpperCase()}`;
    const w = ctx.bold.widthOfTextAtSize(label, 10) + 12;
    const y = Math.min(yL, yR);
    ctx.page.drawRectangle({
      x: MARGIN.x,
      y: y - 3,
      width: w,
      height: 15,
      borderColor: col,
      borderWidth: 1.2,
      color: col,
      opacity: 0.12,
      borderOpacity: 1,
    });
    text(ctx, label, MARGIN.x + 6, y + 1, { size: 10, bold: true, color: col });
    yL = y - 18;
  }

  const yEnd = Math.min(yL, yR) - 2;
  ctx.page.drawLine({
    start: { x: MARGIN.x, y: yEnd },
    end: { x: PAGE.w - MARGIN.x, y: yEnd },
    thickness: 1.2,
    color: ctx.theme.primary,
  });
  return yEnd - 14;
}

/**
 * Tableau "modèle bleu" : par groupe (cycle), en-tête répété par groupe,
 * sous-total montant aligné à droite. Utilisé exclusivement par les
 * documents de vente refondus (FC / PF / BC / BL).
 */
async function drawSalesTable(
  ctx: Ctx,
  titre: string,
  colonnes: Colonne[],
  lignes: DocLigne[],
  yStart: number,
  showSubtotals: boolean,
): Promise<number> {
  const totalW = colonnes.reduce((a, c) => a + c.width, 0);
  const colX: number[] = [];
  let acc = MARGIN.x;
  for (const c of colonnes) {
    colX.push(acc);
    acc += (c.width / totalW) * CONTENT_W;
  }
  const rowH = 18;
  const montantColIdx = colonnes.findIndex((c) => c.key === "montant");

  const drawHeaderRow = (yTop: number): number => {
    ctx.page.drawRectangle({
      x: MARGIN.x,
      y: yTop - rowH,
      width: CONTENT_W,
      height: rowH,
      color: ctx.theme.primary,
    });
    colonnes.forEach((c, i) => {
      const x0 = colX[i];
      const x1 = (colX[i + 1] ?? MARGIN.x + CONTENT_W) - 4;
      const ty = yTop - rowH + 6;
      const label = fitText(ctx, c.label, Math.max(4, x1 - x0 - 2), {
        size: 9,
        bold: true,
      });
      if (c.align === "right")
        textRight(ctx, label, x1, ty, {
          size: 9,
          bold: true,
          color: FABS_COLORS.texteTableau,
        });
      else if (c.align === "center")
        textCenter(ctx, label, (x0 + x1) / 2, ty, {
          size: 9,
          bold: true,
          color: FABS_COLORS.texteTableau,
        });
      else
        text(ctx, label, x0 + 4, ty, {
          size: 9,
          bold: true,
          color: FABS_COLORS.texteTableau,
        });
    });
    return yTop - rowH;
  };

  // Groupement par cycle (fallback : un seul groupe vide)
  const seen: string[] = [];
  const groups: Record<string, DocLigne[]> = {};
  for (const l of lignes) {
    const c = (l.cycle ?? "").toString();
    if (!(c in groups)) {
      seen.push(c);
      groups[c] = [];
    }
    groups[c].push(l);
  }
  const hasCycle = seen.some((c) => c !== "");
  let y = yStart;

  const ensure = async (needed: number) => {
    if (y - needed < BODY_BOTTOM_Y) {
      await drawFooter(ctx);
      ctx.page = ctx.doc.addPage([PAGE.w, PAGE.h]);
      y = drawHeader(ctx, `${titre} (suite)`) - 14;
    }
  };

  for (const cycleName of seen) {
    const items = groups[cycleName];
    await ensure(rowH * 3 + 20);

    // Label de groupe (petit gras, style référence)
    if (hasCycle && cycleName) {
      const label =
        cycleName.charAt(0).toUpperCase() + cycleName.slice(1).toLowerCase();
      text(ctx, label, MARGIN.x, y, {
        size: 10,
        bold: true,
        color: ctx.theme.title,
      });
      y -= 14;
    }

    // En-tête tableau
    const groupTop = y;
    y = drawHeaderRow(y);
    let subtotal = 0;

    for (const ligne of items) {
      const cells = colonnes.map((c, i) => {
        const x0 = colX[i];
        const x1 = (colX[i + 1] ?? MARGIN.x + CONTENT_W) - 4;
        let raw = ligne[c.key];
        if ((raw == null || raw === "") && c.key === "qteCommandee") raw = ligne.qte;
        if ((raw == null || raw === "") && c.key === "qteLivree")
          raw = ligne.qteCommandee ?? ligne.qte;
        if ((raw == null || raw === "") && c.key === "niveau")
          raw = ligne.niveau ?? ligne.cycle;
        let s: string;
        if (raw == null || raw === "") s = "";
        else if (c.percent) s = `${Number(raw)} %`;
        else if (c.money) s = fmtMontant(Number(raw));
        else s = String(raw);
        const maxW = Math.max(4, x1 - x0 - 2);
        const lines = c.wrap
          ? wrapText(ctx, s, maxW, { size: 8.5 })
          : [fitText(ctx, s, maxW, { size: 8.5 })];
        return { c, x0, x1, lines };
      });
      const lineH = 11;
      const maxLines = Math.max(1, ...cells.map((c) => c.lines.length));
      const thisH = Math.max(rowH, maxLines * lineH + 5);
      await ensure(thisH + rowH);
      y -= thisH;
      cells.forEach(({ c, x0, x1, lines }) => {
        lines.forEach((s, li) => {
          const ty = y + thisH - 11 - li * lineH;
          if (c.align === "right") textRight(ctx, s, x1, ty, { size: 8.5 });
          else if (c.align === "center")
            textCenter(ctx, s, (x0 + x1) / 2, ty, { size: 8.5 });
          else text(ctx, s, x0 + 4, ty, { size: 8.5 });
        });
      });
      // Ligne inférieure fine grise entre lignes
      ctx.page.drawLine({
        start: { x: MARGIN.x, y },
        end: { x: PAGE.w - MARGIN.x, y },
        thickness: 0.3,
        color: FABS_COLORS.grisLigne,
      });
      subtotal += Number(ligne.montant ?? 0);
    }

    // Cadre autour du groupe
    ctx.page.drawRectangle({
      x: MARGIN.x,
      y,
      width: CONTENT_W,
      height: groupTop - y,
      borderColor: ctx.theme.primary,
      borderWidth: 0.8,
    });

    // Sous-total : cellule alignée à droite dans la colonne Montant
    if (showSubtotals && montantColIdx >= 0) {
      const x0 = colX[montantColIdx];
      const x1 = PAGE.w - MARGIN.x;
      y -= rowH;
      ctx.page.drawRectangle({
        x: x0,
        y,
        width: x1 - x0,
        height: rowH,
        borderColor: ctx.theme.primary,
        borderWidth: 0.8,
      });
      textRight(ctx, fmtMontant(subtotal), x1 - 6, y + 6, {
        size: 10,
        bold: true,
      });
    }
    y -= 14;
  }
  return y;
}

/** Bloc totaux "modèle bleu" : 4 cartes horizontales + QR code à gauche. */
async function drawTotauxCards(
  ctx: Ctx,
  data: DocBase,
  yStart: number,
  showQr: boolean = true,
): Promise<number> {
  const totalVente = Number(data.totalVente ?? data.montantHT ?? 0);
  const remiseLigne = Number(data.remiseLigneTotal ?? 0);
  const remiseGlobalePct = Number(data.remiseGlobalePct ?? data.remisePct ?? 0);
  const baseApresLigne = totalVente - remiseLigne;
  const remiseGlobale =
    data.remiseGlobale != null
      ? Number(data.remiseGlobale)
      : remiseGlobalePct
        ? Math.round((baseApresLigne * remiseGlobalePct) / 100)
        : Number(data.remise ?? 0);
  const remiseTotale = remiseLigne + remiseGlobale;
  const montantHT = Number(data.montantHT ?? totalVente - remiseTotale);
  const remisePctAff =
    totalVente > 0 ? Math.round((remiseTotale / totalVente) * 1000) / 10 : 0;

  const cards: { label: string; value: string }[] = [
    { label: "Montant", value: fmtMontant(totalVente) },
    { label: "Remise", value: `${remisePctAff.toFixed(2)} %` },
    { label: "Remise", value: fmtMontant(remiseTotale) },
    { label: "Montant HT", value: fmtMontant(montantHT) },
  ];

  // Zone QR (gauche) — laisse la place pour un carré de 72pt (uniquement Facture)
  const qrSize = 72;
  const cardsX0 = showQr ? MARGIN.x + qrSize + 16 : MARGIN.x;
  const cardsW = PAGE.w - MARGIN.x - cardsX0;
  const cardW = (cardsW - 8 * (cards.length - 1)) / cards.length;
  const cardH = 28;
  const y = yStart - cardH * 2 - 6;

  // QR (Facture uniquement)
  if (showQr) try {
    const { default: QRCode } = await import("qrcode");
    const payload = buildQrPayload(data);
    const dataUrl = await QRCode.toDataURL(JSON.stringify(payload), {
      margin: 0,
      width: qrSize * 2,
    });
    const png = await ctx.doc.embedPng(dataUrl);
    ctx.page.drawImage(png, {
      x: MARGIN.x,
      y,
      width: qrSize,
      height: qrSize,
    });
  } catch {
    /* silencieux : le QR n'est pas critique */
  }

  // 4 cartes : en-tête orange + valeur dessous
  cards.forEach((c, i) => {
    const x = cardsX0 + i * (cardW + 8);
    // Header carte (orange plein, texte blanc)
    ctx.page.drawRectangle({
      x,
      y: y + qrSize - cardH,
      width: cardW,
      height: cardH,
      color: ctx.theme.primary,
    });
    textCenter(ctx, c.label, x + cardW / 2, y + qrSize - cardH + 10, {
      size: 10,
      bold: true,
      color: rgb(1, 1, 1),
    });
    // Valeur (bordure orange, texte gras)
    ctx.page.drawRectangle({
      x,
      y: y + qrSize - cardH * 2,
      width: cardW,
      height: cardH,
      borderColor: ctx.theme.primary,
      borderWidth: 0.9,
    });
    textCenter(ctx, c.value, x + cardW / 2, y + qrSize - cardH * 2 + 10, {
      size: 11,
      bold: true,
    });
  });

  return y - 8;
}

/** Documents concernés par le nouveau template "bleu → orange". */
function isSalesTemplateV2(type: DocType): boolean {
  return (
    type === "FC" ||
    type === "PF" ||
    type === "BC" ||
    type === "BL" ||
    type === "BR" ||
    type === "AV" ||
    type === "SP" ||
    type === "BA" ||
    type === "BT"
  );
}

/**
 * Cartes métriques horizontales (style "modèle bleu → orange") sans QR.
 * Utilisé par les documents non-transactionnels : Incidents, Rapports,
 * État de compte, etc. Rendu identique aux cartes du bloc totaux V2.
 */
function drawMetricCards(
  ctx: Ctx,
  items: { label: string; value: string }[],
  yStart: number,
): number {
  if (!items.length) return yStart;
  const cardsW = CONTENT_W;
  const gap = 8;
  const cardW = (cardsW - gap * (items.length - 1)) / items.length;
  const cardH = 28;
  const y = yStart - cardH * 2 - 6;
  items.forEach((c, i) => {
    const x = MARGIN.x + i * (cardW + gap);
    // Header (orange plein, texte blanc)
    ctx.page.drawRectangle({
      x,
      y: y + cardH,
      width: cardW,
      height: cardH,
      color: ctx.theme.primary,
    });
    textCenter(ctx, c.label, x + cardW / 2, y + cardH + 10, {
      size: 10,
      bold: true,
      color: rgb(1, 1, 1),
    });
    // Valeur (bordure orange)
    ctx.page.drawRectangle({
      x,
      y,
      width: cardW,
      height: cardH,
      borderColor: ctx.theme.primary,
      borderWidth: 0.9,
    });
    textCenter(ctx, c.value, x + cardW / 2, y + 10, { size: 11, bold: true });
  });
  return y - 8;
}

/**
 * En-tête V2 : titre large centré + fine ligne orange. Utilisé par les
 * documents "hors vente" (Incidents, Rapport, État de compte) pour
 * s'aligner sur la charte du template refondu.
 */
function drawV2Title(ctx: Ctx, titre: string, yStart: number): number {
  textCenter(ctx, titre, PAGE.w / 2, yStart - 4, {
    size: 18,
    bold: true,
    color: ctx.theme.title,
  });
  const yLine = yStart - 22;
  ctx.page.drawLine({
    start: { x: MARGIN.x, y: yLine },
    end: { x: PAGE.w - MARGIN.x, y: yLine },
    thickness: 1.2,
    color: ctx.theme.primary,
  });
  return yLine - 14;
}

// ----------------------------------------------------------------------------
// V10 : encadré 6 lignes (Total Vente / % Remise / Remise / Montant HT /
// Payé / Total impayé (FCFA)). Total impayé (FCFA) coloré au thème, gras.
// ----------------------------------------------------------------------------
function drawTotauxV10(ctx: Ctx, data: DocBase, yStart: number): number {
  const totalVente = Number(data.totalVente ?? data.montantHT ?? 0);
  const remiseLigne = Number(data.remiseLigneTotal ?? 0);
  const remiseGlobalePct = Number(data.remiseGlobalePct ?? data.remisePct ?? 0);
  const baseApresLigne = totalVente - remiseLigne;
  const remiseGlobale =
    data.remiseGlobale != null
      ? Number(data.remiseGlobale)
      : remiseGlobalePct
        ? Math.round((baseApresLigne * remiseGlobalePct) / 100)
        : Number(data.remise ?? 0);
  const remiseTotale = remiseLigne + remiseGlobale;
  const montantHT = Number(data.montantHT ?? totalVente - remiseTotale);
  const paye = Number(data.paye ?? 0);
  const solde = Number(data.soldeDu ?? montantHT - paye);

  const rows: { label: string; val: string; bold?: boolean; tinted?: boolean }[] = [
    { label: "Total Brut :", val: fmtMontant(totalVente), bold: true },
  ];
  if (remiseLigne) {
    const pctLigne = totalVente > 0 ? Math.round((remiseLigne / totalVente) * 1000) / 10 : 0;
    rows.push({
      label: "Remise Ligne :",
      val: `${fmtMontant(remiseLigne)}  (${pctLigne} %)`,
    });
  }
  if (remiseGlobalePct) rows.push({ label: "% Remise Globale :", val: `${remiseGlobalePct} %` });
  if (remiseGlobale) rows.push({ label: "Remise Globale :", val: fmtMontant(remiseGlobale) });
  // « Total Remises » avec pourcentage effectif
  if (remiseTotale > 0) {
    const pctTotal = totalVente > 0 ? Math.round((remiseTotale / totalVente) * 1000) / 10 : 0;
    rows.push({
      label: "Total Remises :",
      val: `${fmtMontant(remiseTotale)}  (${pctTotal} %)`,
      bold: true,
    });
  }
  rows.push({ label: "Montant HT :", val: fmtMontant(montantHT), bold: true });
  if (paye) rows.push({ label: "Payé :", val: fmtMontant(paye) });
  rows.push({ label: "Net à Payer :", val: fmtMontant(solde), bold: true, tinted: true });

  const boxW = 280;
  const rowH = 16;
  const x0 = PAGE.w - MARGIN.x - boxW;
  const xMid = x0 + 150;
  const xRight = PAGE.w - MARGIN.x - 6;

  rows.forEach((r, i) => {
    const y = yStart - (i + 1) * rowH;
    if (r.tinted) {
      // Net à Payer : encadré orange plein, texte blanc, gras
      ctx.page.drawRectangle({
        x: x0,
        y,
        width: boxW,
        height: rowH,
        color: ctx.theme.primary,
      });
      text(ctx, r.label, x0 + 6, y + 5, { size: 10, bold: true, color: rgb(1, 1, 1) });
      textRight(ctx, r.val, xRight, y + 5, { size: 10, bold: true, color: rgb(1, 1, 1) });
      return;
    }
    ctx.page.drawRectangle({
      x: x0,
      y,
      width: boxW,
      height: rowH,
      borderColor: FABS_COLORS.separateur,
      borderWidth: 0.4,
    });
    text(ctx, r.label, x0 + 6, y + 5, { size: 9, bold: true });
    textRight(ctx, r.val, xRight, y + 5, { size: 9, bold: r.bold });
    ctx.page.drawLine({
      start: { x: xMid, y },
      end: { x: xMid, y: y + rowH },
      thickness: 0.4,
      color: FABS_COLORS.separateur,
    });
  });

  return yStart - rows.length * rowH - 6;
}

function drawTotauxGeneric(ctx: Ctx, data: DocBase, yStart: number): number {
  const xLabel = PAGE.w - MARGIN.x - 200;
  const xVal = PAGE.w - MARGIN.x;
  let y = yStart;
  const line = (label: string, val: string, bold = false) => {
    text(ctx, label, xLabel, y, { size: 9, bold });
    textRight(ctx, val, xVal, y, { size: 9, bold });
    y -= 13;
  };
  // TVA supprimée : plus de distinction HT/TTC — une seule ligne « Total ».
  if (data.remise) line("Remise :", `${fmtMontant(data.remise)} FCFA`);
  const total = data.totalTTC ?? data.montantHT;
  if (total != null) line("Total :", `${fmtMontant(total)} FCFA`, true);
  return y;
}

// ----------------------------------------------------------------------------
// QR code
// ----------------------------------------------------------------------------
async function drawQRCode(
  ctx: Ctx,
  payload: Record<string, unknown>,
  x: number,
  y: number,
  size = 80,
) {
  const { default: QRCode } = await import("qrcode");
  const dataUrl = await QRCode.toDataURL(JSON.stringify(payload), { margin: 0, width: size * 2 });
  const png = await ctx.doc.embedPng(dataUrl);
  ctx.page.drawImage(png, { x, y, width: size, height: size });
}

function drawSignature(ctx: Ctx, label: string, xRight: number, y: number) {
  textRight(ctx, label, xRight, y, { size: 9, bold: true });
  const f = ctx.bold;
  const w = f.widthOfTextAtSize(label, 9);
  ctx.page.drawLine({
    start: { x: xRight - w, y: y - 2 },
    end: { x: xRight, y: y - 2 },
    thickness: 0.6,
    color: FABS_COLORS.noir,
  });
}

// ----------------------------------------------------------------------------
// Code-barres CODE128 du numéro de document (canvas → PNG)
// ----------------------------------------------------------------------------
async function drawBarcode(ctx: Ctx, value: string, x: number, y: number, w = 140, h = 26) {
  try {
    const { default: JsBarcode } = await import("jsbarcode");
    const canvas = document.createElement("canvas");
    JsBarcode(canvas, value, {
      format: "CODE128",
      displayValue: false,
      margin: 0,
      height: 60,
      width: 2,
    });
    const dataUrl = canvas.toDataURL("image/png");
    const png = await ctx.doc.embedPng(dataUrl);
    ctx.page.drawImage(png, { x, y, width: w, height: h });
    textCenter(ctx, value, x + w / 2, y - 7, { size: 6.5, color: FABS_COLORS.gris });
  } catch {
    /* silencieux : le code-barres est décoratif */
  }
}

// ----------------------------------------------------------------------------
// Bloc de signatures multi-zones (Établi / Contrôlé / Validé / Cachet client)
// ----------------------------------------------------------------------------
function drawSignaturesBlock(ctx: Ctx, yTop: number): number {
  const labels = ["Établi par", "Contrôlé par", "Validé par", "Cachet & Signature client"];
  const colW = CONTENT_W / labels.length;
  const boxH = 50;
  const y = yTop - boxH;
  labels.forEach((lab, i) => {
    const x = MARGIN.x + i * colW;
    ctx.page.drawRectangle({
      x: x + 2,
      y,
      width: colW - 4,
      height: boxH,
      borderColor: FABS_COLORS.separateur,
      borderWidth: 0.5,
    });
    text(ctx, lab, x + 6, y + boxH - 11, { size: 8, bold: true, color: ctx.theme.title });
    text(ctx, "Date : ____ / ____ / ______", x + 6, y + 6, {
      size: 6.5,
      color: FABS_COLORS.gris,
    });
  });
  return y - 6;
}

// ----------------------------------------------------------------------------
// Initialisation document
// ----------------------------------------------------------------------------
export type CtxInit = {
  title: string;
  reference: string;
  date?: string | Date;
  signatureLabel?: string;
  showQr?: boolean;
  showBarcode?: boolean;
  /** Type document pour résoudre template_per_type depuis document_settings. */
  docType?: SettingsDocType;
};

async function loadLogoBytes(): Promise<Uint8Array> {
  const res = await fetch(fabsLogoUrl);
  if (!res.ok) throw new Error("Logo officiel PDF indisponible.");
  return new Uint8Array(await res.arrayBuffer());
}

async function newCtx(init: CtxInit): Promise<Ctx> {
  const doc = await PDFDocument.create();
  const page = doc.addPage([PAGE.w, PAGE.h]);
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const italic = await doc.embedFont(StandardFonts.HelveticaOblique);
  const boldItalic = await doc.embedFont(StandardFonts.HelveticaBoldOblique);
  const bytes = await loadLogoBytes();
  let logoImg: PDFImage | null;
  try {
    logoImg = await doc.embedPng(bytes);
  } catch {
    try {
      logoImg = await doc.embedJpg(bytes);
    } catch {
      throw new Error("Le logo officiel PDF n'est pas un PNG/JPG valide.");
    }
  }
  // Date + heure réelles de génération (récupérées automatiquement à chaque
  // impression / export PDF). Le corps conserve la date métier (data.date).
  const when = new Date();
  const heure = `${String(when.getHours()).padStart(2, "0")}:${String(when.getMinutes()).padStart(2, "0")}`;
  return {
    doc,
    page,
    font,
    bold,
    italic,
    boldItalic,
    theme: resolveTheme(init.docType),
    logoImg,
    title: init.title,
    reference: init.reference,
    dateStr: fmtDate(when),
    heureStr: heure,
    signatureLabel: init.signatureLabel ?? "La Comptabilité",
    showQr: init.showQr ?? true,
    showBarcode: init.showBarcode ?? true,
  };
}

async function finalize(ctx: Ctx): Promise<Blob> {
  const pages = ctx.doc.getPages();
  const total = pages.length;
  pages.forEach((page, index) => {
    const showFooter = total === 1 || index === total - 1;
    if (!showFooter) return;
    const label = `Page ${index + 1} / ${total}`;
    const size = 8;
    const width = ctx.font.widthOfTextAtSize(label, size);
    page.drawText(label, {
      x: PAGE.w - MARGIN.x - width,
      y: 16,
      size,
      font: ctx.font,
      color: FABS_COLORS.gris,
    });
  });
  // Règle ERP §22 : en-tête + pied uniquement sur la 1re / dernière page.
  // On masque les zones à ne pas afficher avec un rectangle blanc plein
  // largeur, dessiné en dernier au-dessus du chrome déjà rendu.
  const white = rgb(1, 1, 1);
  const headerBandH = MARGIN.top; // couvre logo + société + séparateur
  const footerBandH = MARGIN.bottom + 75; // couvre QR + siège + signature
  pages.forEach((page, index) => {
    const showHeader = total === 1 || index === 0;
    const showFooter = total === 1 || index === total - 1;
    if (!showHeader) {
      page.drawRectangle({
        x: 0,
        y: PAGE.h - headerBandH,
        width: PAGE.w,
        height: headerBandH,
        color: white,
      });
    }
    if (!showFooter) {
      page.drawRectangle({
        x: 0,
        y: 0,
        width: PAGE.w,
        height: footerBandH,
        color: white,
      });
    }
  });
  const bytes = await ctx.doc.save();
  return new Blob([bytes as unknown as BlobPart], { type: "application/pdf" });
}

// QR JSON canonique — partagé par la génération et le contrôle automatisé
export function buildQrPayload(data: DocBase): Record<string, unknown> {
  return {
    ref: data.reference,
    client: data.clientNom ?? "",
    date: fmtDate(data.date),
    total: Math.round(Number(data.totalVente ?? data.montantHT ?? 0)),
    solde: Math.round(Number(data.soldeDu ?? 0)),
  };
}

export function downloadBlob(blob: Blob, filename: string) {
  // Android WebView (APK) : le protocole blob: n'est pas géré par le
  // gestionnaire de téléchargement natif. On passe par un pont JS injecté
  // par MainActivity qui enregistre le fichier dans Téléchargements.
  const androidBridge = (
    globalThis as unknown as {
      AndroidFileSaver?: { saveBase64: (n: string, b: string, m: string) => void };
    }
  ).AndroidFileSaver;
  const ua = typeof navigator !== "undefined" ? navigator.userAgent : "";
  const isAndroid = /Android/i.test(ua);
  if (androidBridge) {
    try {
      const reader = new FileReader();
      reader.onloadend = () => {
        try {
          const result = String(reader.result ?? "");
          const base64 = result.includes(",") ? result.split(",")[1] : result;
          androidBridge.saveBase64(filename, base64, blob.type || "application/pdf");
        } catch {
          androidFallback(blob, filename);
        }
      };
      reader.onerror = () => androidFallback(blob, filename);
      reader.readAsDataURL(blob);
      return;
    } catch {
      androidFallback(blob, filename);
      return;
    }
  }
  if (isAndroid) {
    // Pont natif absent (APK ancien ou WebView externe) : on bascule sur la
    // solution de secours (data: URL + nouvelle fenêtre) qui reste compatible
    // avec le gestionnaire de téléchargement Android.
    androidFallback(blob, filename);
    return;
  }
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/**
 * Fallback Android sans pont natif : convertit le Blob en data: URL et ouvre
 * la ressource dans un nouvel onglet. Le gestionnaire PDF du système propose
 * alors "Télécharger" / "Ouvrir avec". Fonctionne en WebView Android standard
 * et en navigateur Chrome mobile.
 */
function androidFallback(blob: Blob, filename: string) {
  const reader = new FileReader();
  reader.onloadend = () => {
    const dataUrl = String(reader.result ?? "");
    // Tentative 1 : <a download> avec data: URL (Chrome Android récent).
    try {
      const a = document.createElement("a");
      a.href = dataUrl;
      a.download = filename;
      a.rel = "noopener";
      a.target = "_blank";
      document.body.appendChild(a);
      a.click();
      a.remove();
    } catch {
      // Tentative 2 : ouverture directe pour laisser l'OS gérer.
      window.open(dataUrl, "_blank");
    }
  };
  reader.readAsDataURL(blob);
}

// ----------------------------------------------------------------------------
// Colonnes par type
// ----------------------------------------------------------------------------
// Colonnes "modèle bleu → orange" : la classe (niveau) est la 1re colonne
// et remplace le regroupement en bandeau — l'utilisateur voit directement
// la classe de chaque ligne.
const COLS_FACTURE: Colonne[] = [
  { key: "niveau", label: "Classe", width: 1.0, align: "center" },
  { key: "codeArticle", label: "Code Article", width: 1.3, align: "center" },
  { key: "reference", label: "Désignation", width: 2.8, align: "left", wrap: true },
  { key: "qte", label: "Qté", width: 0.6, align: "center" },
  { key: "prixUnitaire", label: "Prix Unitaire (FCFA)", width: 1.3, align: "right", money: true },
  { key: "montant", label: "Montant (FCFA)", width: 1.3, align: "right", money: true },
];

const COLS_BC: Colonne[] = [
  { key: "niveau", label: "Classe", width: 1.0, align: "center" },
  { key: "codeArticle", label: "Code Article", width: 1.3, align: "center" },
  { key: "reference", label: "Désignation", width: 2.5, align: "left", wrap: true },
  { key: "qteCommandee", label: "Qté Cmd", width: 0.8, align: "center" },
  { key: "prixUnitaire", label: "Prix Unit. (FCFA)", width: 1.1, align: "right", money: true },
  { key: "remisePct", label: "Remise", width: 0.8, align: "right", percent: true },
  { key: "montant", label: "Montant (FCFA)", width: 1.2, align: "right", money: true },
];

const COLS_BL: Colonne[] = [
  { key: "niveau", label: "Classe", width: 1.0, align: "center" },
  { key: "codeArticle", label: "Code Article", width: 1.3, align: "center" },
  { key: "reference", label: "Référence", width: 3.8, align: "left", wrap: true },
  { key: "qteCommandee", label: "Qté Cmd", width: 1.0, align: "center" },
  { key: "qteLivree", label: "Qté Livrée", width: 1.0, align: "center" },
];

const COLS_BR: Colonne[] = [
  { key: "codeArticle", label: "Code Article", width: 1.2, align: "center" },
  { key: "reference", label: "Référence", width: 2.1, align: "left", wrap: true },
  { key: "qteRetournee", label: "Qté", width: 0.7, align: "center" },
  { key: "motif", label: "Motif", width: 1.3, align: "left", wrap: true },
  { key: "prixUnitaire", label: "Prix Unit.", width: 1.0, align: "right", money: true },
  { key: "remisePct", label: "Rem. %", width: 0.7, align: "right" },
  { key: "montant", label: "Montant", width: 1.1, align: "right", money: true },
];

const COLS_AV: Colonne[] = [
  { key: "codeArticle", label: "Code Article", width: 1.4, align: "center" },
  { key: "reference", label: "Référence", width: 3.3, align: "left", wrap: true },
  { key: "qte", label: "Qté", width: 0.8, align: "center" },
  { key: "prixUnitaire", label: "Prix Unitaire", width: 1.3, align: "right", money: true },
  { key: "montant", label: "Montant Avoir", width: 1.3, align: "right", money: true },
];

const COLS_SP: Colonne[] = [
  { key: "codeArticle", label: "Code Article", width: 1.3, align: "center" },
  { key: "reference", label: "Référence", width: 2.2, align: "left", wrap: true },
  { key: "qteLivree", label: "Quantité", width: 1, align: "center" },
  { key: "motif", label: "Motif / Bénéficiaire", width: 2.2, align: "left", wrap: true },
];

// ----------------------------------------------------------------------------
// Générateurs : documents avec tableau de lignes
// ----------------------------------------------------------------------------
async function buildTableDoc(
  type: DocType,
  cols: Colonne[],
  data: DocBase,
  opts: {
    qr?: boolean;
    barcode?: boolean;
    groupByCycle?: boolean;
    modePaiementGauche?: string;
    mentionRouge?: string;
    signatures?: "comptable" | "bl";
    partyLabel?: string;
  } = {},
): Promise<Blob> {
  const sigLabel =
    type === "BA"
      ? "Responsable de la gestion des stocks"
      : opts.signatures === "bl"
        ? "Signature du Réceptionnaire"
        : "La Comptabilité";
  const DT_MAP: Record<DocType, SettingsDocType> = {
    FC: "facture",
    PF: "proforma",
    BC: "bon_commande",
    BL: "bon_livraison",
    BR: "bon_retour",
    AV: "avoir",
    RP: "recu",
    BP: "bulletin",
    SP: "bon_livraison",
    BA: "bon_commande",
    BT: "bon_livraison",
  };
  const ctx = await newCtx({
    title: TITRES[type],
    reference: data.reference,
    date: data.date,
    signatureLabel: sigLabel,
    showQr: opts.qr ?? true,
    showBarcode: opts.barcode ?? true,
    docType: DT_MAP[type],
  });
  let y = drawHeader(ctx, TITRES[type]);
  y -= 12;

  // ------------------------------------------------------------------
  // Nouveau template "bleu → orange" : FC / PF / BC / BL exclusivement.
  // ------------------------------------------------------------------
  if (isSalesTemplateV2(type)) {
    // Le QR est intégré au bloc totaux (à côté des cartes) : on désactive
    // celui du pied pour éviter les doublons.
    ctx.showQr = false;
    y = drawSalesInfos(ctx, data, y);
    const skipTotaux = type === "BL" || type === "SP" || type === "BT";
    y = await drawSalesTable(
      ctx,
      TITRES[type],
      cols,
      data.lignes ?? [],
      y,
      !skipTotaux,
    );
    if (!skipTotaux) {
      const need = 90;
      if (y - need < BODY_BOTTOM_Y) {
        y = await addContinuationPage(ctx, TITRES[type]);
      }
      // QR code uniquement sur la Facture (FC) ; retiré des autres documents de vente.
      y = await drawTotauxCards(ctx, data, y, type === "FC");
    }
    if (opts.mentionRouge) {
      text(ctx, opts.mentionRouge, MARGIN.x, Math.max(y, BODY_BOTTOM_Y + 20) - 8, {
        size: 8,
        color: FABS_COLORS.rouge,
        bold: true,
      });
    }
    await drawFooter(ctx);
    return finalize(ctx);
  }

  y = drawInfosTransaction(ctx, data, y, opts.partyLabel);
  y = await drawTableau(ctx, TITRES[type], cols, data.lignes ?? [], y, opts.groupByCycle ?? false);

  // V10 : encadré 6 lignes pour les documents de vente, totaux génériques sinon
  const useV10 = type === "FC" || type === "PF" || type === "AV" || type === "BC" || type === "BL";
  const neededAfterTable =
    (useV10 ? 112 : 64) + (opts.mentionRouge ? 20 : 0) + (opts.signatures === "bl" ? 45 : 0);
  if (y - neededAfterTable < BODY_BOTTOM_Y) {
    y = await addContinuationPage(ctx, TITRES[type]);
  }
  const yTotaux = y;
  // BL / SP : documents non chiffrés (pas de totaux monétaires affichés).
  const skipTotaux = type === "BL" || type === "SP";
  const yTotauxBottom = skipTotaux
    ? yTotaux
    : useV10
      ? drawTotauxV10(ctx, data, yTotaux)
      : drawTotauxGeneric(ctx, data, yTotaux);

  // Bloc gauche : mode de paiement (QR + signature désormais dessinés dans le pied)
  let yLeft = yTotaux;
  if (opts.modePaiementGauche) {
    text(ctx, opts.modePaiementGauche, MARGIN.x, yLeft, { size: 9, bold: true });
    yLeft -= 14;
  }

  if (opts.mentionRouge) {
    text(ctx, opts.mentionRouge, MARGIN.x, Math.min(yLeft, yTotauxBottom) - 14, {
      size: 8,
      color: FABS_COLORS.rouge,
      bold: true,
    });
  }

  // Bloc signatures multi-zones (Établi / Contrôlé / Validé / Cachet client)
  // sur les documents commerciaux (vente + commande/livraison/retour/avoir).
  if (
    type === "FC" ||
    type === "PF" ||
    type === "BC" ||
    type === "BL" ||
    type === "BR" ||
    type === "AV"
  ) {
    const yBloc = Math.min(yLeft, yTotauxBottom) - 14;
    if (yBloc - 60 < BODY_BOTTOM_Y) {
      await addContinuationPage(ctx, TITRES[type]);
      drawSignaturesBlock(ctx, PAGE.h - MARGIN.top - 12);
    } else {
      drawSignaturesBlock(ctx, yBloc);
    }
  }

  await drawFooter(ctx);
  return finalize(ctx);
}

// ============================================================================
// Déclaration d'incident de stock — même charte graphique que tous les autres
// documents ERP (en-tête FABS-CI, coordonnées, pied orange, pagination).
// ============================================================================
export type IncidentLignePdf = {
  numero: number;
  reference: string;
  designation: string;
  quantite: number;
  unite?: string | null;
  valeurUnitaire?: number | null;
  valeurTotale?: number | null;
  observation?: string | null;
};

export type IncidentPdfData = {
  numero: string;
  dateIncident: string | Date;
  heureIncident?: string | null;
  depot?: string | null;
  magasin?: string | null;
  responsable?: string | null;
  typeIncident: string;
  statut?: DocStatut | null;
  gravite?: string | null;
  declarant?: string | null;
  dateDeclaration?: string | Date | null;
  motif?: string | null;
  observations?: string | null;
  lignes: IncidentLignePdf[];
};

function drawIncidentInfos(ctx: Ctx, data: IncidentPdfData, yStart: number): number {
  const colR = MARGIN.x + CONTENT_W / 2;
  const kv = (label: string, value: string | null | undefined, x: number, y: number) => {
    text(ctx, `${label} :`, x, y, { size: 8.5, bold: true, color: ctx.theme.primary });
    text(ctx, value && value.trim() ? value : "—", x + 90, y, { size: 9 });
  };
  const dt = fmtDate(data.dateIncident);
  const heure = data.heureIncident ?? "";
  const dtDecl = data.dateDeclaration ? fmtDate(data.dateDeclaration) : "";

  let yL = yStart;
  let yR = yStart;
  text(ctx, "INCIDENT", MARGIN.x, yL, { size: 10, bold: true, color: ctx.theme.primary });
  text(ctx, "DÉCLARATION", colR, yR, { size: 10, bold: true, color: ctx.theme.primary });
  yL -= 14;
  yR -= 14;

  kv("Numéro", shortRef(data.numero), MARGIN.x, yL); yL -= 13;
  kv("Date", dt, MARGIN.x, yL); yL -= 13;
  kv("Heure", heure, MARGIN.x, yL); yL -= 13;
  kv("Dépôt", data.depot, MARGIN.x, yL); yL -= 13;
  kv("Magasin", data.magasin, MARGIN.x, yL); yL -= 13;
  kv("Responsable", data.responsable, MARGIN.x, yL); yL -= 13;

  kv("Type", data.typeIncident, colR, yR); yR -= 13;
  kv("Gravité", data.gravite, colR, yR); yR -= 13;
  kv("Déclarant", data.declarant, colR, yR); yR -= 13;
  kv("Déclaré le", dtDecl, colR, yR); yR -= 13;

  if (data.statut && data.statut.label) {
    const col = data.statut.color ? hex(data.statut.color) : FABS_COLORS.gris;
    const label = `Statut : ${data.statut.label.toUpperCase()}`;
    const w = ctx.bold.widthOfTextAtSize(label, 10) + 12;
    ctx.page.drawRectangle({
      x: colR - 2,
      y: yR - 3,
      width: w,
      height: 15,
      borderColor: col,
      borderWidth: 1.2,
      color: col,
      opacity: 0.12,
      borderOpacity: 1,
    });
    text(ctx, label, colR + 4, yR + 1, { size: 10, bold: true, color: col });
    yR -= 18;
  }

  const yEnd = Math.min(yL, yR) - 4;
  hline(ctx, yEnd);
  return yEnd - 8;
}

function drawMotifBox(ctx: Ctx, motif: string | null | undefined, yStart: number): number {
  if (!motif || !motif.trim()) return yStart;
  text(ctx, "MOTIF DE L'INCIDENT", MARGIN.x, yStart, {
    size: 9,
    bold: true,
    color: ctx.theme.primary,
  });
  let y = yStart - 12;
  const lines = wrapText(ctx, motif, CONTENT_W - 12, { size: 9 });
  const lineH = 12;
  const boxH = Math.max(28, lines.length * lineH + 10);
  ctx.page.drawRectangle({
    x: MARGIN.x,
    y: y - boxH + 4,
    width: CONTENT_W,
    height: boxH,
    borderColor: FABS_COLORS.separateur,
    borderWidth: 0.6,
    color: FABS_COLORS.grisClair,
  });
  let ty = y - 6;
  for (const l of lines) {
    text(ctx, l, MARGIN.x + 6, ty, { size: 9 });
    ty -= lineH;
  }
  y -= boxH;
  return y - 4;
}

function drawIncidentSignatures(ctx: Ctx, yTop: number): number {
  const labels = [
    "Gestionnaire de Stock",
    "Responsable Logistique",
    "Directeur Représentant",
    "Direction Générale",
  ];
  const colW = CONTENT_W / labels.length;
  const boxH = 60;
  const y = yTop - boxH;
  labels.forEach((lab, i) => {
    const x = MARGIN.x + i * colW;
    ctx.page.drawRectangle({
      x: x + 2,
      y,
      width: colW - 4,
      height: boxH,
      borderColor: FABS_COLORS.separateur,
      borderWidth: 0.5,
    });
    text(ctx, lab, x + 6, y + boxH - 11, { size: 8, bold: true, color: ctx.theme.title });
    text(ctx, "Date : ____ / ____ / ______", x + 6, y + 16, {
      size: 6.5,
      color: FABS_COLORS.gris,
    });
    text(ctx, "Signature & cachet", x + 6, y + 6, { size: 6.5, color: FABS_COLORS.gris });
  });
  return y - 6;
}

const COLS_INCIDENT: Colonne[] = [
  { key: "codeArticle", label: "N°", width: 0.4, align: "center" },
  { key: "reference", label: "Référence", width: 1.2, align: "left", wrap: true },
  { key: "designation", label: "Désignation", width: 2.6, align: "left", wrap: true },
  { key: "qte", label: "Qté", width: 0.6, align: "center" },
  { key: "unite", label: "Unité", width: 0.6, align: "center" },
  { key: "prixUnitaire", label: "Val. unit.", width: 1.1, align: "right", money: true },
  { key: "montant", label: "Val. totale", width: 1.2, align: "right", money: true },
  { key: "motif", label: "Observation", width: 1.5, align: "left", wrap: true },
];

export async function generateIncidentPDF(data: IncidentPdfData): Promise<Blob> {
  const TITRE = "DÉCLARATION D'INCIDENT DE STOCK";
  const ctx = await newCtx({
    title: TITRE,
    reference: data.numero,
    date: data.dateIncident,
    signatureLabel: "Le Gestionnaire de Stock",
    showQr: shouldShowQr("IN"),
    showBarcode: true,
    docType: "bon_commande",
  });
  let y = drawHeader(ctx, TITRE);
  y -= 8;
  // Titre V2 (grand + ligne orange) — cohérent avec les documents de vente.
  y = drawV2Title(ctx, TITRE, y);
  y = drawIncidentInfos(ctx, data, y);
  y = drawMotifBox(ctx, data.motif, y);

  const lignes: DocLigne[] = data.lignes.map((l) => ({
    codeArticle: String(l.numero),
    reference: l.reference,
    designation: l.designation,
    qte: l.quantite,
    unite: l.unite ?? "",
    prixUnitaire: l.valeurUnitaire ?? 0,
    montant: l.valeurTotale ?? (l.valeurUnitaire ?? 0) * (l.quantite ?? 0),
    motif: l.observation ?? "",
  }));

  y = await drawTableau(ctx, TITRE, COLS_INCIDENT, lignes, y, false);

  // Totaux — cartes horizontales V2 (sans QR).
  const nbProduits = lignes.length;
  const qteTotale = lignes.reduce((s, l) => s + Number(l.qte ?? 0), 0);
  const valeurTotale = lignes.reduce((s, l) => s + Number(l.montant ?? 0), 0);
  const need = 90;
  if (y - need < BODY_BOTTOM_Y) y = await addContinuationPage(ctx, TITRE);
  y = drawMetricCards(ctx, [
    { label: "Nb produits", value: String(nbProduits) },
    { label: "Quantité totale", value: String(qteTotale) },
    { label: "Valeur des pertes", value: `${fmtMontant(valeurTotale)} FCFA` },
  ], y);

  // Observations libres (si présentes)
  if (data.observations && data.observations.trim()) {
    const lines = wrapText(ctx, data.observations, CONTENT_W - 12, { size: 8 });
    const need = 20 + lines.length * 11;
    if (y - need < BODY_BOTTOM_Y) y = await addContinuationPage(ctx, TITRE);
    text(ctx, "OBSERVATIONS", MARGIN.x, y, { size: 9, bold: true, color: ctx.theme.primary });
    y -= 12;
    for (const l of lines) {
      text(ctx, l, MARGIN.x, y, { size: 8, color: FABS_COLORS.gris });
      y -= 11;
    }
    y -= 6;
  }

  // Signatures 4 zones ERP
  if (y - 70 < BODY_BOTTOM_Y) y = await addContinuationPage(ctx, TITRE);
  drawIncidentSignatures(ctx, y);

  await drawFooter(ctx);
  return finalize(ctx);
}

// ============================================================================
// Rapport d'incidents (liste agrégée) — même charte FABS-CI.
// ============================================================================
export type RapportIncidentRow = {
  numero: string;
  date: string | Date;
  type: string;
  magasin?: string | null;
  nbProduits: number;
  quantite: number;
  valeur: number;
  statut?: string | null;
};

export type RapportIncidentsData = {
  reference: string;
  periodeLabel: string;
  filtresLabel?: string | null;
  lignes: RapportIncidentRow[];
};

const COLS_RAPPORT_INCIDENTS: Colonne[] = [
  { key: "codeArticle", label: "N°", width: 0.5, align: "center" },
  { key: "reference", label: "Numéro incident", width: 1.5, align: "left" },
  { key: "designation", label: "Type", width: 1.8, align: "left", wrap: true },
  { key: "matiere", label: "Magasin", width: 1.4, align: "left", wrap: true },
  { key: "qte", label: "Nb prod.", width: 0.7, align: "center" },
  { key: "qteCommandee", label: "Quantité", width: 0.8, align: "center" },
  { key: "montant", label: "Valeur (FCFA)", width: 1.3, align: "right", money: true },
  { key: "unite", label: "Statut", width: 1.0, align: "center" },
];

export async function generateRapportIncidentsPDF(data: RapportIncidentsData): Promise<Blob> {
  const TITRE = "RAPPORT D'INCIDENTS DE STOCK";
  const ctx = await newCtx({
    title: TITRE,
    reference: data.reference,
    date: new Date(),
    signatureLabel: "Le Gestionnaire de Stock",
    showQr: false,
    showBarcode: true,
    docType: "bon_commande",
  });
  let y = drawHeader(ctx, TITRE);
  y -= 8;
  y = drawV2Title(ctx, TITRE, y);

  text(ctx, "PÉRIODE :", MARGIN.x, y, { size: 9, bold: true, color: ctx.theme.primary });
  text(ctx, data.periodeLabel, MARGIN.x + 60, y, { size: 9 });
  y -= 13;
  if (data.filtresLabel) {
    text(ctx, "FILTRES :", MARGIN.x, y, { size: 9, bold: true, color: ctx.theme.primary });
    text(ctx, data.filtresLabel, MARGIN.x + 60, y, { size: 9 });
    y -= 13;
  }
  hline(ctx, y);
  y -= 10;

  const lignes: DocLigne[] = data.lignes.map((r, i) => ({
    codeArticle: String(i + 1),
    reference: r.numero,
    designation: r.type,
    matiere: r.magasin ?? "",
    qte: r.nbProduits,
    qteCommandee: r.quantite,
    montant: r.valeur,
    unite: r.statut ?? "",
  }));
  y = await drawTableau(ctx, TITRE, COLS_RAPPORT_INCIDENTS, lignes, y, false);

  // Totaux — cartes horizontales V2 (sans QR).
  const nb = data.lignes.length;
  const qte = data.lignes.reduce((s, r) => s + Number(r.quantite || 0), 0);
  const val = data.lignes.reduce((s, r) => s + Number(r.valeur || 0), 0);
  if (y - 90 < BODY_BOTTOM_Y) y = await addContinuationPage(ctx, TITRE);
  y = drawMetricCards(ctx, [
    { label: "Nb incidents", value: String(nb) },
    { label: "Quantité totale", value: String(qte) },
    { label: "Valeur des pertes", value: `${fmtMontant(val)} FCFA` },
  ], y);

  await drawFooter(ctx);
  return finalize(ctx);
}

export async function generateFacturePDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Facture", data);
}

export async function generateProformaPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Proforma", data);
}

export async function generateBonCommandePDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Commande", data);
}

export async function generateBonLivraisonPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Bon de Livraison", data);
}

export async function generateBonRetourPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Bon de Retour" as any, data);
}

export async function generateBonRemiseSpecimensPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Spécimens", data);
}

const COLS_BA: Colonne[] = [
  { key: "codeArticle", label: "Code Article", width: 1.2, align: "center" },
  { key: "reference", label: "Désignation", width: 2.8, align: "left", wrap: true },
  { key: "qte", label: "Qté Reçue", width: 0.9, align: "center" },
  { key: "prixUnitaire", label: "Prix Unit. (FCFA)", width: 1.3, align: "right", money: true },
  { key: "remisePct", label: "Remise (%)", width: 0.9, align: "center" },
  { key: "montant", label: "Montant (FCFA)", width: 1.3, align: "right", money: true },
];

/** Bon de réception d'un approvisionnement (fournisseur). */
export async function generateApprovisionnementPDF(data: DocBase): Promise<Blob> {
  return buildTableDoc("BA", COLS_BA, data, {
    qr: false,
    barcode: true,
    groupByCycle: false,
    partyLabel: "FOURNISSEUR",
  });
}

const COLS_BT: Colonne[] = [
  { key: "codeArticle", label: "Code Article", width: 1.3, align: "center" },
  { key: "reference", label: "Désignation", width: 3.5, align: "left", wrap: true },
  { key: "qte", label: "Quantité", width: 1.0, align: "center" },
];

/** Bon de transfert inter-dépôts (mouvement stock entre dépôts). */
export async function generateBonTransfertPDF(data: DocBase): Promise<Blob> {
  return buildTableDoc("BT", COLS_BT, data, {
    qr: false,
    barcode: true,
    groupByCycle: false,
    partyLabel: "DÉPÔT DESTINATAIRE",
  });
}

export async function generateAvoirPDF(
  data: DocBase & { factureReference?: string },
): Promise<Blob> {
  return generateUnifiedCommercialPDF("Avoir", data);
}

// ----------------------------------------------------------------------------
// Reçu de paiement (pas de tableau)
// ----------------------------------------------------------------------------
export type RecuData = DocBase & {
  montantEnLettres?: string;
  montant?: number;
  factureReference?: string;
  numeroCheque?: string;
  resteDu?: number;
  /** Banque (si chèque / virement). */
  banque?: string | null;
  /** Référence transaction Mobile Money. */
  referenceMobileMoney?: string | null;
  /** Montant total de la facture concernée. */
  factureMontantTotal?: number | null;
  /** Total déjà payé sur la facture AVANT ce paiement. */
  factureMontantPayeAvant?: number | null;
  /** Observations libres. */
  observations?: string | null;
  /** Devise (par défaut FCFA). */
  devise?: string | null;
};

export async function generateRecuPaiementPDF(data: RecuData): Promise<Blob> {
  const ctx = await newCtx({
    title: TITRES.RP,
    reference: data.reference,
    date: data.date,
    signatureLabel: "La Comptabilité",
    showQr: false,
    docType: "recu",
  });
  // Charte FABS-CI imposée sur le reçu de paiement (orange, pas de bleu).
  ctx.theme = THEMES.fabs_ci;

  const devise = data.devise?.trim() || "FCFA";
  const montant = Number(data.montant ?? 0);
  const totalFacture =
    data.factureMontantTotal != null ? Number(data.factureMontantTotal) : null;
  const dejaPaye =
    data.factureMontantPayeAvant != null ? Number(data.factureMontantPayeAvant) : null;
  const resteCalc =
    totalFacture != null && dejaPaye != null
      ? Math.max(0, totalFacture - dejaPaye - montant)
      : data.resteDu != null
        ? Number(data.resteDu)
        : null;

  let y = drawHeader(ctx, TITRES.RP);
  y -= 24; // Augmentation de l'espace après l'en-tête (V10)

  // Deux colonnes : Client (gauche) / Paiement (droite)
  const colLx = MARGIN.x;
  const colRx = MARGIN.x + CONTENT_W / 2 + 8;
  const colW = CONTENT_W / 2 - 8;
  const yTop = y;

  const drawBlockTitle = (label: string, x: number, yy: number) => {
    ctx.page.drawRectangle({
      x,
      y: yy - 4,
      width: colW,
      height: 16,
      color: FABS_COLORS.grisClair,
    });
    text(ctx, label, x + 6, yy, { size: 9, bold: true, color: ctx.theme.title });
  };
  const kv = (label: string, val: string, x: number, yy: number) => {
    text(ctx, label, x, yy, { size: 8.5, bold: true });
    text(ctx, fitText(ctx, val || "—", colW - 92, { size: 8.5 }), x + 92, yy, {
      size: 8.5,
    });
  };

  drawBlockTitle("INFORMATIONS CLIENT", colLx, y);
  drawBlockTitle("INFORMATIONS PAIEMENT", colRx, y);
  y -= 22;

  let yL = y;
  let yR = y;
  const step = 14;

  kv("Client :", data.clientNom ?? "", colLx, yL); yL -= step;
  kv("Code client :", data.codeClient ?? "", colLx, yL); yL -= step;
  kv("Téléphone :", data.clientTel ?? "", colLx, yL); yL -= step;
  kv("Adresse :", data.adresseClient ?? "", colLx, yL); yL -= step;
  kv("Ville :", data.villeClient ?? "", colLx, yL); yL -= step;

  kv("Référence :", data.reference, colRx, yR); yR -= step;
  kv("Date paiement :", fmtDate(data.date), colRx, yR); yR -= step;
  kv("Facture :", data.factureReference ?? "—", colRx, yR); yR -= step;
  kv("Mode :", data.modePaiement ?? "", colRx, yR); yR -= step;
  if (data.banque) { kv("Banque :", data.banque, colRx, yR); yR -= step; }
  if (data.numeroCheque) { kv("N° chèque :", data.numeroCheque, colRx, yR); yR -= step; }
  if (data.referenceMobileMoney) {
    kv("Réf. Mobile Money :", data.referenceMobileMoney, colRx, yR); yR -= step;
  }
  kv("Montant :", `${fmtMontant(montant)} ${devise}`, colRx, yR); yR -= step;

  y = Math.min(yL, yR) - 6;
  hline(ctx, y);
  y -= 18;

  // Représentant commercial
  const rep = data.representant?.trim();
  text(ctx, "Représentant :", MARGIN.x, y, { size: 9, bold: true });
  text(ctx, rep && rep.length ? rep : "Non renseigné", MARGIN.x + 100, y, {
    size: 9,
    color: rep ? FABS_COLORS.noir : FABS_COLORS.gris,
  });
  y -= 22;

  // Tableau situation facture
  text(ctx, "SITUATION DE LA FACTURE", MARGIN.x, y, {
    size: 10,
    bold: true,
    color: ctx.theme.title,
  });
  y -= 10;

  const tblX = MARGIN.x;
  const tblW = CONTENT_W;
  const col1 = tblW * 0.65;
  const rowH = 18;
  const rows: [string, string, boolean?][] = [
    ["Montant de la facture", totalFacture != null ? `${fmtMontant(totalFacture)} ${devise}` : "—"],
    ["Total déjà payé (avant ce reçu)", dejaPaye != null ? `${fmtMontant(dejaPaye)} ${devise}` : "—"],
    ["Paiement du jour", `${fmtMontant(montant)} ${devise}`],
    ["Total impayé (FCFA)", resteCalc != null ? `${fmtMontant(resteCalc)} ${devise}` : "—", true],
  ];
  // Header
  ctx.page.drawRectangle({
    x: tblX, y: y - rowH + 4, width: tblW, height: rowH,
    color: ctx.theme.tableHdrBg,
  });
  text(ctx, "Désignation", tblX + 6, y - 8, { size: 9, bold: true, color: ctx.theme.tableHdrTxt });
  textRight(ctx, "Montant", tblX + tblW - 6, y - 8, {
    size: 9, bold: true, color: ctx.theme.tableHdrTxt,
  });
  y -= rowH;

  rows.forEach(([label, val, bold], i) => {
    if (i % 2 === 1) {
      ctx.page.drawRectangle({
        x: tblX, y: y - rowH + 4, width: tblW, height: rowH,
        color: FABS_COLORS.grisClair,
      });
    }
    if (bold) {
      ctx.page.drawRectangle({
        x: tblX, y: y - rowH + 4, width: tblW, height: rowH,
        color: FABS_COLORS.grisClair,
      });
    }
    text(ctx, label, tblX + 6, y - 8, { size: 9, bold: !!bold });
    textRight(ctx, val, tblX + tblW - 6, y - 8, {
      size: 9,
      bold: !!bold,
      color: bold ? ctx.theme.title : FABS_COLORS.noir,
    });
    y -= rowH;
  });
  // Bordure tableau
  ctx.page.drawRectangle({
    x: tblX, y: y + 4, width: tblW, height: (rows.length + 1) * rowH,
    borderColor: FABS_COLORS.grisLigne, borderWidth: 0.6,
  });
  // Séparateur colonne
  ctx.page.drawLine({
    start: { x: tblX + col1, y: y + 4 },
    end: { x: tblX + col1, y: y + 4 + (rows.length + 1) * rowH },
    thickness: 0.4,
    color: FABS_COLORS.grisLigne,
  });
  y -= 14;

  // Montant en lettres
  const lettres = data.montantEnLettres || nombreEnLettresFr(Math.round(montant));
  text(ctx, "Arrêté le présent reçu à la somme de :", MARGIN.x, y, {
    size: 9,
    bold: true,
  });
  y -= 14;
  const phrase = `${capitalizeFirst(lettres)} (${fmtMontant(montant)}) francs CFA.`;
  drawWrapped(ctx, phrase, MARGIN.x, y, CONTENT_W, {
    size: 10,
    bold: true,
    color: ctx.theme.title,
    lineHeight: 13,
  });
  y -= 30;

  // Observations
  text(ctx, "Observations :", MARGIN.x, y, { size: 9, bold: true });
  y -= 6;
  ctx.page.drawRectangle({
    x: MARGIN.x, y: y - 34, width: CONTENT_W, height: 34,
    borderColor: FABS_COLORS.grisLigne, borderWidth: 0.6,
  });
  if (data.observations) {
    drawWrapped(ctx, data.observations, MARGIN.x + 6, y - 10, CONTENT_W - 12, {
      size: 8.5,
      lineHeight: 11,
    });
  }
  y -= 46;

  // Signatures (2 colonnes)
  const sigY = Math.max(y, BODY_BOTTOM_Y + 10);
  const sigLabels = ["Le Client", "La Comptabilité"];
  const sigW = CONTENT_W / sigLabels.length;
  
  sigLabels.forEach((lbl, i) => {
    const cx = MARGIN.x + sigW * i + sigW / 2;
    textCenter(ctx, lbl, cx, sigY, { size: 9, bold: true });
    ctx.page.drawLine({
      start: { x: MARGIN.x + sigW * i + 20, y: sigY - 34 },
      end: { x: MARGIN.x + sigW * (i + 1) - 20, y: sigY - 34 },
      thickness: 0.5,
      color: FABS_COLORS.grisLigne,
    });
    textCenter(ctx, "Signature", cx, sigY - 44, {
      size: 8,
      color: FABS_COLORS.gris,
    });
  });

  await drawFooter(ctx);
  return finalize(ctx);
}

// ---------------------------------------------------------------------------
// Helpers texte / nombres pour le reçu
// ---------------------------------------------------------------------------
function capitalizeFirst(s: string): string {
  if (!s) return s;
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function drawWrapped(
  ctx: Ctx,
  s: string,
  x: number,
  y: number,
  maxW: number,
  opts: { size?: number; bold?: boolean; color?: RGB; lineHeight?: number } = {},
) {
  const size = opts.size ?? 9;
  const lh = opts.lineHeight ?? size + 3;
  const lines = wrapText(ctx, s, maxW, { size, bold: opts.bold });
  let yy = y;
  for (const ln of lines) {
    text(ctx, ln, x, yy, opts);
    yy -= lh;
  }
}

/** Convertit un entier positif (< 1 000 000 000) en toutes lettres (français). */
export function nombreEnLettresFr(n: number): string {
  n = Math.max(0, Math.floor(n));
  if (n === 0) return "zéro";
  const units = [
    "", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf",
    "dix", "onze", "douze", "treize", "quatorze", "quinze", "seize",
    "dix-sept", "dix-huit", "dix-neuf",
  ];
  const tens: Record<number, string> = {
    2: "vingt", 3: "trente", 4: "quarante", 5: "cinquante", 6: "soixante", 8: "quatre-vingt",
  };
  function under100(x: number): string {
    if (x < 20) return units[x];
    if (x < 70) {
      const t = Math.floor(x / 10);
      const u = x % 10;
      if (u === 0) return tens[t];
      if (u === 1 && t !== 8) return `${tens[t]} et un`;
      return `${tens[t]}-${units[u]}`;
    }
    if (x < 80) {
      const u = x - 60;
      if (u === 11) return "soixante et onze";
      return `soixante-${units[u]}`;
    }
    if (x < 100) {
      const u = x - 80;
      if (u === 0) return "quatre-vingts";
      return `quatre-vingt-${units[u]}`;
    }
    return "";
  }
  function under1000(x: number): string {
    const c = Math.floor(x / 100);
    const r = x % 100;
    let s = "";
    if (c === 1) s = "cent";
    else if (c > 1) s = `${units[c]} cent${r === 0 ? "s" : ""}`;
    if (r > 0) s = s ? `${s} ${under100(r)}` : under100(r);
    return s;
  }
  const parts: string[] = [];
  const millions = Math.floor(n / 1_000_000);
  const milliers = Math.floor((n % 1_000_000) / 1000);
  const reste = n % 1000;
  if (millions > 0) {
    parts.push(millions === 1 ? "un million" : `${under1000(millions)} millions`);
  }
  if (milliers > 0) {
    if (milliers === 1) parts.push("mille");
    else parts.push(`${under1000(milliers)} mille`);
  }
  if (reste > 0) parts.push(under1000(reste));
  return parts.join(" ");
}

// ----------------------------------------------------------------------------
// Bulletin de paie (deux colonnes gains / retenues)
// ----------------------------------------------------------------------------
export type BulletinData = {
  reference: string;
  date: string;
  employeNom: string;
  periode?: string;
  gains: { label: string; montant: number }[];
  retenues: { label: string; montant: number }[];
  totalBrut: number;
  totalRetenues: number;
  netAPayer: number;
  /** Bloc identité (optionnel) : rendu si fourni. */
  identite?: {
    matricule?: string;
    poste?: string;
    departement?: string;
    dateEmbauche?: string;
    categorie?: string;
    joursTravailles?: number;
    modeReglement?: string;
  };
  /** Charges patronales (optionnel) : rendu sous les totaux. */
  patronales?: { label: string; montant: number }[];
  coutEmployeur?: number;
  baseImposable?: number;
};

export async function generateBulletinPaiePDF(data: BulletinData): Promise<Blob> {
  const ctx = await newCtx({
    title: TITRES.BP,
    reference: data.reference,
    date: data.date,
    signatureLabel: "La Comptabilité",
    showQr: false,
    docType: "bulletin",
  });
  let y = drawHeader(ctx, TITRES.BP);
  y -= 18;

  text(ctx, `Employé : ${data.employeNom}`, MARGIN.x, y, { size: 10, bold: true });
  textRight(ctx, `Période : ${data.periode ?? ""}`, PAGE.w - MARGIN.x, y, { size: 9 });
  y -= 14;
  text(ctx, `Réf. : ${data.reference}`, MARGIN.x, y, { size: 9, color: FABS_COLORS.gris });
  y -= 18;

  // Bloc identité (2 colonnes) si fourni
  if (data.identite) {
    const id = data.identite;
    const left: [string, string | undefined][] = [
      ["Matricule", id.matricule],
      ["Poste", id.poste],
      ["Département", id.departement],
    ];
    const right: [string, string | undefined][] = [
      ["Date d'embauche", id.dateEmbauche],
      ["Catégorie", id.categorie],
      ["Jours travaillés", id.joursTravailles ? String(id.joursTravailles) : undefined],
    ];
    const colRx = MARGIN.x + CONTENT_W / 2 + 10;
    for (let i = 0; i < 3; i++) {
      const [lk, lv] = left[i];
      const [rk, rv] = right[i];
      if (lv) text(ctx, `${lk} : ${lv}`, MARGIN.x, y, { size: 9 });
      if (rv) text(ctx, `${rk} : ${rv}`, colRx, y, { size: 9 });
      y -= 12;
    }
    y -= 6;
  }

  const colG = MARGIN.x;
  const colR = MARGIN.x + CONTENT_W / 2 + 10;
  const valG = MARGIN.x + CONTENT_W / 2 - 10;
  const valR = PAGE.w - MARGIN.x;

  text(ctx, "GAINS", colG, y, { size: 10, bold: true, color: FABS_COLORS.bleuTitre });
  text(ctx, "RETENUES", colR, y, { size: 10, bold: true, color: FABS_COLORS.bleuTitre });
  y -= 6;
  hline(ctx, y);
  y -= 14;

  const rows = Math.max(data.gains.length, data.retenues.length);
  let yy = y;
  const drawBulletinColumns = (topY: number) => {
    text(ctx, "GAINS", colG, topY, { size: 10, bold: true, color: FABS_COLORS.bleuTitre });
    text(ctx, "RETENUES", colR, topY, { size: 10, bold: true, color: FABS_COLORS.bleuTitre });
    hline(ctx, topY - 6);
    return topY - 20;
  };
  for (let i = 0; i < rows; i++) {
    if (yy < BODY_BOTTOM_Y + 24) {
      await drawFooter(ctx);
      ctx.page = ctx.doc.addPage([PAGE.w, PAGE.h]);
      yy = drawHeader(ctx, `${TITRES.BP} (suite)`) - 18;
      yy = drawBulletinColumns(yy);
    }
    const g = data.gains[i];
    const r = data.retenues[i];
    if (g) {
      text(ctx, g.label, colG, yy, { size: 9 });
      textRight(ctx, fmtMontant(g.montant), valG, yy, { size: 9 });
    }
    if (r) {
      text(ctx, r.label, colR, yy, { size: 9 });
      textRight(ctx, fmtMontant(r.montant), valR, yy, { size: 9 });
    }
    yy -= 14;
  }

  yy -= 4;
  hline(ctx, yy + 8);
  text(ctx, "TOTAL BRUT", colG, yy, { size: 9, bold: true });
  textRight(ctx, fmtMontant(data.totalBrut), valG, yy, { size: 9, bold: true });
  text(ctx, "TOTAL RETENUES", colR, yy, { size: 9, bold: true });
  textRight(ctx, fmtMontant(data.totalRetenues), valR, yy, { size: 9, bold: true });
  yy -= 24;

  ctx.page.drawRectangle({
    x: MARGIN.x,
    y: yy - 6,
    width: CONTENT_W,
    height: 22,
    color: FABS_COLORS.grisClair,
  });
  text(ctx, "NET À PAYER :", MARGIN.x + 8, yy, { size: 11, bold: true });
  textRight(ctx, `${fmtMontant(data.netAPayer)} FCFA`, PAGE.w - MARGIN.x - 8, yy, {
    size: 11,
    bold: true,
    color: FABS_COLORS.bleuTitre,
  });
  yy -= 28;

  // Section charges patronales (optionnelle)
  if (data.patronales && data.patronales.length > 0) {
    text(ctx, "CHARGES PATRONALES", MARGIN.x, yy, {
      size: 10,
      bold: true,
      color: FABS_COLORS.bleuTitre,
    });
    hline(ctx, yy - 6);
    yy -= 18;
    for (const p of data.patronales) {
      if (yy < BODY_BOTTOM_Y + 24) break;
      text(ctx, p.label, MARGIN.x, yy, { size: 9 });
      textRight(ctx, fmtMontant(p.montant), PAGE.w - MARGIN.x, yy, { size: 9 });
      yy -= 12;
    }
    if (typeof data.coutEmployeur === "number") {
      yy -= 4;
      hline(ctx, yy + 6);
      text(ctx, "COÛT TOTAL EMPLOYEUR", MARGIN.x, yy, { size: 10, bold: true });
      textRight(ctx, `${fmtMontant(data.coutEmployeur)} FCFA`, PAGE.w - MARGIN.x, yy, {
        size: 10,
        bold: true,
        color: FABS_COLORS.orange,
      });
    }
  }

  await drawFooter(ctx);
  return finalize(ctx);
}

// ----------------------------------------------------------------------------
// État de compte client — version enrichie (historique complet + résumé)
// ----------------------------------------------------------------------------
export type EtatCompteLigne = {
  date: string;
  type: string; // Report | Facture | Paiement | Avoir | Commande | Livraison
  reference: string;
  libelle?: string | null;
  factureReference?: string | null;
  debit?: number;
  credit?: number;
};

export type EtatCompteCommandeRow = {
  reference: string;
  date: string;
  montant: number;
  statut: string;
  qteCommandee?: number;
  qteLivree?: number;
  qteRestante?: number;
};

export type EtatComptePaiementRow = {
  date: string;
  reference: string;
  mode: string;
  numeroRecu?: string | null;
  montant: number;
};

export type EtatCompteAgeing = {
  nonEchu: number;
  j0_30: number;
  j31_60: number;
  j61_90: number;
  j90plus: number;
};

export type EtatCompteData = {
  reference: string;
  /** Bornes de la période affichée (ex. exercice). */
  periodeDebut?: string | null;
  periodeFin?: string | null;
  /** Bloc client complet — les champs "flat" restent supportés pour compat. */
  client?: {
    code?: string | null;
    nom: string;
    adresse?: string | null;
    telephone?: string | null;
    email?: string | null;
    representant?: string | null;
  };
  // Champs plats (compat ancien appel)
  clientNom?: string;
  clientTel?: string | null;
  representant?: string | null;

  soldeOuverture?: number;
  lignes: EtatCompteLigne[];
  commandes?: EtatCompteCommandeRow[];
  paiements?: EtatComptePaiementRow[];

  totalCommandes?: number;
  totalFacture?: number;
  totalPaye?: number;
  totalAvoirs?: number;

  ageing?: EtatCompteAgeing | null;
  /** Note affichée sous les totaux — utile quand aucun mouvement valide n'existe. */
  note?: string | null;
};

const MODE_PAIEMENT_LABEL: Record<string, string> = {
  espece: "Espèces",
  especes: "Espèces",
  cheque: "Chèque",
  virement: "Virement",
  orange_money: "Orange Money",
  mtn_money: "MTN Money",
  moov_money: "Moov Money",
  wave: "Wave",
  carte: "Carte",
  autre: "Autre",
};

const STATUT_COMMANDE_LABEL: Record<string, string> = {
  livree: "Livrée",
  livree_partiel: "Partiellement livrée",
  partiellement_livree: "Partiellement livrée",
  en_attente: "En attente",
  brouillon: "Brouillon",
  validee: "Validée",
  confirmee: "Confirmée",
  annulee: "Annulée",
};

export async function generateEtatCompteClientPDF(data: EtatCompteData): Promise<Blob> {
  return generateUnifiedStatementPDF(data);
}

async function legacy_generateEtatCompteClientPDF(data: EtatCompteData): Promise<Blob> {
  const client = {
    nom: data.clientNom ?? "",
    code: (data as any).codeClient ?? null,
    adresse: (data as any).adresseClient ?? null,
    telephone: data.clientTel ?? null,
    email: (data as any).emailClient ?? null,
    representant: data.representant ?? null,
  };
  const ctx = await newCtx({
    title: "État de Compte Client",
    reference: data.reference,
    date: new Date(),
    signatureLabel: "La Comptabilité",
    showQr: false,
    docType: "etat_compte",
  });
  let y = drawHeader(ctx, "RELEVÉ DE COMPTE CLIENT");
  y -= 24; 



  // ---------- Bloc infos client + période ----------
  const colR = MARGIN.x + CONTENT_W / 2;
  let yL = y;
  let yR = y;
  text(ctx, "Référence :", MARGIN.x, yL, { size: 10, bold: true });
  text(ctx, shortRef(data.reference), MARGIN.x + 80, yL, {
    size: 11, bold: true, color: ctx.theme.primary,
  });
  text(ctx, "Date :", colR, yR, { size: 10, bold: true });
  text(ctx, fmtDate(new Date()), colR + 80, yR, { size: 11, bold: true });
  yL -= 16; yR -= 16;

  if (data.periodeDebut || data.periodeFin) {
    const per = `${data.periodeDebut ? fmtDate(data.periodeDebut) : "—"} au ${data.periodeFin ? fmtDate(data.periodeFin) : "—"}`;
    text(ctx, "Période :", colR, yR, { size: 10, bold: true });
    text(ctx, per, colR + 80, yR, { size: 10 });
    yR -= 14;
  }

  text(ctx, fitText(ctx, client.nom, CONTENT_W / 2 - 12, { size: 11, bold: true }), MARGIN.x, yL, {
    size: 11,
    bold: true,
  });
  yL -= 15;
  if (client.code) {
    text(ctx, `Code : ${client.code}`, MARGIN.x, yL, { size: 9, color: FABS_COLORS.gris });
    yL -= 12;
  }
  if (client.adresse) {
    text(ctx, client.adresse, MARGIN.x, yL, { size: 9, color: FABS_COLORS.gris });
    yL -= 12;
  }
  if (client.telephone) {
    text(ctx, `Tél : ${client.telephone}`, MARGIN.x, yL, { size: 9, color: FABS_COLORS.gris });
    yL -= 12;
  }
  if (client.email) {
    text(ctx, `Email : ${client.email}`, MARGIN.x, yL, { size: 9, color: FABS_COLORS.gris });
    yL -= 12;
  }
  if (client.representant) {
    text(ctx, "Représentant :", colR, yR, { size: 10, bold: true });
    text(ctx, client.representant, colR + 80, yR, { size: 10, bold: true });
    yR -= 14;
  }

  y = Math.min(yL, yR) - 4;
  ctx.page.drawLine({
    start: { x: MARGIN.x, y },
    end: { x: PAGE.w - MARGIN.x, y },
    thickness: 1.2,
    color: ctx.theme.primary,
  });
  y -= 14;

  // ---------- Solde du relevé : uniquement les opérations visibles ----------
  let totalDebit = 0;
  let totalCredit = 0;
  for (const l of data.lignes) {
    totalDebit += Number(l.debit ?? 0);
    totalCredit += Number(l.credit ?? 0);
  }
  const soldeFinal = totalDebit - totalCredit;

  const ensureSpace = async (h: number, titreSuite: string) => {
    if (y - h < BODY_BOTTOM_Y) {
      await drawFooter(ctx);
      ctx.page = ctx.doc.addPage([PAGE.w, PAGE.h]);
      y = drawHeader(ctx, titreSuite) - 18;
    }
  };

  // ---------- Utilitaire : tableau ----------
  type TCol = { label: string; w: number; align: "left" | "right" };
  const drawTable = async (
    titre: string,
    cols: TCol[],
    rows: string[][],
    opts?: { footerRow?: string[]; emptyMsg?: string; highlightLast?: boolean },
  ) => {
    await ensureSpace(50, "État de Compte (suite)");
    y -= 4;
    text(ctx, titre, MARGIN.x, y, { size: 11, bold: true, color: ctx.theme.title });
    y -= 12;

    const totalW = cols.reduce((a, c) => a + c.w, 0);
    const colX: number[] = [];
    let acc = MARGIN.x;
    for (const c of cols) {
      colX.push(acc);
      acc += (c.w / totalW) * CONTENT_W;
    }
    const rowH = 15;

    const drawHead = (yTop: number) => {
      ctx.page.drawRectangle({
        x: MARGIN.x,
        y: yTop - rowH,
        width: CONTENT_W,
        height: rowH,
        color: FABS_COLORS.orange,
      });
      cols.forEach((c, i) => {
        const x0 = colX[i];
        const x1 = (colX[i + 1] ?? MARGIN.x + CONTENT_W) - 4;
        const ty = yTop - rowH + 4;
        const label = fitText(ctx, c.label, Math.max(4, x1 - x0 - 4), { size: 6.7, bold: true });
        if (c.align === "right")
          textRight(ctx, label, x1, ty, { size: 6.7, bold: true, color: FABS_COLORS.texteTableau });
        else text(ctx, label, x0 + 3, ty, { size: 6.7, bold: true, color: FABS_COLORS.texteTableau });
      });
      return yTop - rowH;
    };

    y = drawHead(y);

    if (rows.length === 0) {
      y -= rowH;
      text(ctx, opts?.emptyMsg ?? "Aucune donnée.", MARGIN.x + 4, y + 4, {
        size: 8, color: FABS_COLORS.gris,
      });
      return;
    }

    for (let i = 0; i < rows.length; i++) {
      if (y < BODY_BOTTOM_Y + 40) {
        await drawFooter(ctx);
        ctx.page = ctx.doc.addPage([PAGE.w, PAGE.h]);
        y = drawHeader(ctx, "État de Compte (suite)") - 12;
        y = drawHead(y);
      }
      y -= rowH;
      const isLast = i === rows.length - 1;
      if (opts?.highlightLast && isLast) {
        ctx.page.drawRectangle({
          x: MARGIN.x, y, width: CONTENT_W, height: rowH, color: hex("#FFF4E5"),
        });
      } else if (i % 2 === 1) {
        ctx.page.drawRectangle({
          x: MARGIN.x, y, width: CONTENT_W, height: rowH, color: FABS_COLORS.grisClair,
        });
      }
      cols.forEach((c, k) => {
        const x0 = colX[k];
        const x1 = (colX[k + 1] ?? MARGIN.x + CONTENT_W) - 4;
        const ty = y + 4;
        const valRaw = rows[i][k] ?? "";
        const val = fitText(ctx, valRaw, Math.max(4, x1 - x0 - 4), {
          size: 7,
          bold: opts?.highlightLast && isLast,
        });
        const bold = opts?.highlightLast && isLast;
        
        // Coloration en rouge pour les lignes de type retour/avoir dans l'historique
        const isMvtTable = cols.length === 7;
        const isRetourRow = isMvtTable && rows[i][1] === "Retour / Avoir";
        const color = isRetourRow ? FABS_COLORS.rouge : undefined;

        if (c.align === "right") textRight(ctx, val, x1, ty, { size: 7, bold, color });
        else text(ctx, val, x0 + 3, ty, { size: 7, bold, color });
      });
    }

    if (opts?.footerRow) {
      await ensureSpace(rowH + 4, "État de Compte (suite)");
      y -= rowH;
      ctx.page.drawRectangle({
        x: MARGIN.x, y, width: CONTENT_W, height: rowH, color: hex("#FFF4E5"),
      });
      cols.forEach((c, k) => {
        const x0 = colX[k];
        const x1 = (colX[k + 1] ?? MARGIN.x + CONTENT_W) - 4;
        const ty = y + 4;
        const val = opts.footerRow?.[k] ?? "";
        if (c.align === "right") textRight(ctx, val, x1, ty, { size: 8, bold: true });
        else text(ctx, val, x0 + 3, ty, { size: 8, bold: true });
      });
    }
  };

  // ---------- Historique chronologique unique ----------
  // Ne conserver que les opérations à impact comptable : facture / paiement / avoir / régularisation.
  const isComptable = (typ: string) => {
    const t = (typ || "").toLowerCase();
    return (
      t.includes("facture") ||
      t.includes("paiement") ||
      t.includes("règlement") ||
      t.includes("reglement") ||
      t.includes("avoir") ||
      t.includes("retour") ||
      t.includes("régularisation") ||
      t.includes("regularisation") ||
      t.includes("ajustement")
    );
  };
  const lignesComptables = data.lignes.filter(
    (l) => Number(l.debit ?? 0) !== 0 || Number(l.credit ?? 0) !== 0,
  ).filter((l) => isComptable(l.type));

  const sortedLignes = [...lignesComptables].sort(
    (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime(),
  );

  const mvtCols: TCol[] = [
    { label: "Date", w: 1.0, align: "left" },
    { label: "Type d'opération", w: 1.3, align: "left" },
    { label: "Référence", w: 1.5, align: "left" },
    { label: "N° de commande", w: 1.5, align: "left" },
    { label: "Débit (+) FCFA", w: 1.2, align: "right" },
    { label: "Crédit (-) FCFA", w: 1.2, align: "right" },
    { label: "Solde après opération", w: 1.4, align: "right" },
  ];

  const mvtRows: string[][] = [];
  let solde = 0;
  for (const l of sortedLignes) {
    const debit = Number(l.debit ?? 0);
    const credit = Number(l.credit ?? 0);
    solde += debit - credit;
    const typeLow = (l.type || "").toLowerCase();
    const isFact = typeLow.includes("facture");
    const isRemise = typeLow.includes("remise") || typeLow.includes("avoir") || typeLow.includes("retour");
    const typeAffiche = typeLow.includes("avoir") || typeLow.includes("retour")
      ? "Retour / Avoir"
      : typeLow.includes("paiement") || typeLow.includes("règlement") || typeLow.includes("reglement")
        ? "Paiement"
        : "Facture";
    mvtRows.push([
      fmtDate(l.date),
      typeAffiche,
      l.reference || "—",
      isFact ? (l.reference || "—") : (l.factureReference || "—"),
      
      debit ? fmtMontant(debit) : "",
      credit ? fmtMontant(credit) : "",
      fmtMontant(solde),
    ]);
  }

  await drawTable(
    `Historique du compte — Solde à ce jour : ${fmtMontant(soldeFinal)} FCFA`,
    mvtCols,
    mvtRows,
    {
    emptyMsg: "Aucune facture, aucun paiement et aucun avoir sur la période sélectionnée.",
    highlightLast: false,
    },
  );

  // ---------- Encadré récapitulatif ----------
  if (sortedLignes.length > 0) {
    const totalFactures = sortedLignes
      .filter((l) => (l.type || "").toLowerCase().includes("facture"))
      .reduce((a, l) => a + Number(l.debit ?? 0), 0);
    const totalPaiements = sortedLignes
      .filter((l) => {
        const t = (l.type || "").toLowerCase();
        return t.includes("paiement") || t.includes("règlement") || t.includes("reglement");
      })
      .reduce((a, l) => a + Number(l.credit ?? 0), 0);
    const totalAvoirs = sortedLignes
      .filter((l) => {
        const t = (l.type || "").toLowerCase();
        return t.includes("avoir") || t.includes("retour");
      })
      .reduce((a, l) => a + Number(l.credit ?? 0), 0);

    const recapLines: Array<[string, string]> = [
      ["Total factures (FCFA)", fmtMontant(totalFactures)],
      ["Total paiements (FCFA)", fmtMontant(totalPaiements)],
      ["Total avoirs / retours (FCFA)", fmtMontant(totalAvoirs)],
      ["Total impayé (FCFA)", fmtMontant(soldeFinal)],
      ["Édité le", fmtDate(new Date())],
    ];
    const boxH = recapLines.length * 14 + 18;
    await ensureSpace(boxH + 20, "État de Compte (suite)");
    y -= 18;
    const boxW = 260;
    const boxX = PAGE.w - MARGIN.x - boxW;
    ctx.page.drawRectangle({
      x: boxX,
      y: y - boxH,
      width: boxW,
      height: boxH,
      borderColor: FABS_COLORS.orange,
      borderWidth: 0.8,
    });
    ctx.page.drawRectangle({
      x: boxX,
      y: y - 3,
      width: boxW,
      height: 3,
      color: FABS_COLORS.orange,
    });
    let ry = y - 18;
    recapLines.forEach(([label, val], i) => {
      const isImpaye = label.toLowerCase().includes("impayé") || label.toLowerCase().includes("solde");
      const isRemise = label.toLowerCase().includes("remise") || label.toLowerCase().includes("avoir") || label.toLowerCase().includes("retour");
      const color = (isImpaye || isRemise) ? FABS_COLORS.rouge : undefined;
      const last = i === recapLines.length - 2;
      text(ctx, label, boxX + 8, ry, { size: 8.5, bold: last, color });
      textRight(ctx, val, boxX + boxW - 8, ry, {
        size: last ? 10 : 8.5,
        bold: true,
        color: last ? ctx.theme.title : color,
      });
      ry -= 14;
    });
    y = y - boxH - 6;
  }

  // ---------- Note (cas vide / info) ----------
  if (sortedLignes.length === 0) {
    y -= 14;
    text(
      ctx,
      "Aucune facture, aucun paiement et aucun avoir sur la période sélectionnée.",
      MARGIN.x,
      y,
      { size: 9, color: FABS_COLORS.gris },
    );
    y -= 12;
  }
  await drawFooter(ctx);
  return finalize(ctx);
}
