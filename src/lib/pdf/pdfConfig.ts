// Configuration centralisée de tous les PDF de l'ERP.
// Modifie ces valeurs sans toucher aux générateurs.

export type RGB = [number, number, number];

export const PDF_COLORS = {
  orange: [255, 98, 0] as RGB,
  navy: [10, 37, 64] as RGB,
  muted: [100, 100, 100] as RGB,
  black: [0, 0, 0] as RGB,
  white: [255, 255, 255] as RGB,
};

export const PDF_HEADER = {
  height: 28, // hauteur du bandeau navy (mm)
  bg: PDF_COLORS.navy,
  companyColor: PDF_COLORS.white,
  titleColor: PDF_COLORS.orange,
  companyFontSize: 16,
  metaFontSize: 8,
  titleFontSize: 18,
};

export const PDF_FOOTER = {
  fontSize: 8,
  color: PDF_COLORS.muted,
  mentionsY: 12, // distance depuis le bas (mm)
  contactY: 6,
};

export const PDF_PAGINATION = {
  fontSize: 9,
  color: PDF_COLORS.muted,
  bottom: 6, // distance depuis le bas (mm)
  right: 14, // distance depuis la droite (mm)
  format: (page: number, total: number) => `Page ${page} / ${total}`,
};

// Marges des tableaux (top doit dépasser la hauteur de l'en-tête).
export const PDF_MARGINS = {
  document: { top: 32, bottom: 22 },
  journal: { top: 42, bottom: 18 },
};

export const PDF_TABLE = {
  // Charte lisibilité renforcée : en-têtes/pieds en gras, corps plus grand.
  headStyles: {
    fillColor: PDF_COLORS.navy,
    textColor: 255,
    fontStyle: "bold" as const,
    fontSize: 10,
    cellPadding: 3,
  },
  footStyles: {
    fillColor: PDF_COLORS.orange,
    textColor: 255,
    fontStyle: "bold" as const,
    fontSize: 10,
    cellPadding: 3,
  },
  bodyStyles: { cellPadding: 2.6, lineColor: [220, 220, 220] as RGB },
  bodyFontSize: 10,
  journalFontSize: 9,
};

// ────────────────────────────────────────────────────────────────────────────
// MODÈLES DE DOCUMENTS (issus de l'ancien projet — document_templates.py)
// 5 mises en page sélectionnables pour les documents de vente.
// ────────────────────────────────────────────────────────────────────────────

export type BuiltinTemplateId = "classique" | "moderne" | "premium" | "corporate" | "administratif";

// Un id peut être un modèle intégré OU un uuid de modèle personnalisé.
export type PdfTemplateId = string;

export type PdfTemplate = {
  id: PdfTemplateId;
  label: string;
  description: string;
  font: "helvetica" | "times";
  headerVariant: "classique" | "moderne" | "premium" | "corporate" | "administratif";
  headerBg: RGB | null;
  companyColor: RGB;
  titleColor: RGB;
  tableHeadFill: RGB;
  accent: RGB;
  totalBoxed: boolean;
  headerHeight: number;
  bodyTop: number;
  /** Mention de pied de page personnalisée (optionnel). */
  footerNote?: string;
  /** true pour les modèles créés par l'utilisateur. */
  custom?: boolean;
};

export const BUILTIN_TEMPLATES: PdfTemplate[] = [
  {
    id: "classique",
    label: "Classique Pro",
    description: "Bandeau navy, titre orange aligné à droite. Sobre et institutionnel.",
    font: "helvetica",
    headerVariant: "classique",
    headerBg: PDF_COLORS.navy,
    companyColor: PDF_COLORS.white,
    titleColor: PDF_COLORS.orange,
    tableHeadFill: PDF_COLORS.navy,
    accent: PDF_COLORS.orange,
    totalBoxed: false,
    headerHeight: 28,
    bodyTop: 38,
  },
  {
    id: "moderne",
    label: "Moderne Bleu",
    description: "Bandeau centré, société en haut, totaux dans un bloc navy.",
    font: "helvetica",
    headerVariant: "moderne",
    headerBg: PDF_COLORS.navy,
    companyColor: PDF_COLORS.white,
    titleColor: PDF_COLORS.orange,
    tableHeadFill: PDF_COLORS.navy,
    accent: PDF_COLORS.navy,
    totalBoxed: true,
    headerHeight: 40,
    bodyTop: 48,
  },
  {
    id: "premium",
    label: "Premium",
    description: "Police serif, société centrée, filet orange, totaux encadrés.",
    font: "times",
    headerVariant: "premium",
    headerBg: null,
    companyColor: PDF_COLORS.navy,
    titleColor: PDF_COLORS.orange,
    tableHeadFill: PDF_COLORS.navy,
    accent: PDF_COLORS.orange,
    totalBoxed: true,
    headerHeight: 38,
    bodyTop: 46,
  },
  {
    id: "corporate",
    label: "Corporate Orange",
    description: "Bandeau orange plein, titre blanc. Très visible.",
    font: "helvetica",
    headerVariant: "corporate",
    headerBg: PDF_COLORS.orange,
    companyColor: PDF_COLORS.white,
    titleColor: PDF_COLORS.white,
    tableHeadFill: PDF_COLORS.orange,
    accent: PDF_COLORS.orange,
    totalBoxed: false,
    headerHeight: 28,
    bodyTop: 38,
  },
  {
    id: "administratif",
    label: "Élégant Administratif",
    description: "Police serif, en-tête sobre sur fond blanc, accent rouge.",
    font: "times",
    headerVariant: "administratif",
    headerBg: null,
    companyColor: PDF_COLORS.navy,
    titleColor: [220, 38, 38],
    tableHeadFill: PDF_COLORS.navy,
    accent: [220, 38, 38],
    totalBoxed: true,
    headerHeight: 30,
    bodyTop: 40,
  },
];

const STORAGE_KEY = "fabs.pdf.template";
const CUSTOM_KEY = "fabs.pdf.customTemplates";

/** Modèle par défaut utilisé en fallback. */
export const DEFAULT_TEMPLATE = BUILTIN_TEMPLATES[0];

/** Cache synchrone des modèles personnalisés (hydraté depuis la base). */
function readCustomCache(): PdfTemplate[] {
  try {
    if (typeof localStorage === "undefined") return [];
    const raw = localStorage.getItem(CUSTOM_KEY);
    if (!raw) return [];
    const list = JSON.parse(raw) as PdfTemplate[];
    return Array.isArray(list) ? list.map((t) => ({ ...t, custom: true })) : [];
  } catch {
    return [];
  }
}

/** Met à jour le cache local des modèles personnalisés. */
export function setCustomTemplatesCache(list: PdfTemplate[]): void {
  try {
    localStorage.setItem(CUSTOM_KEY, JSON.stringify(list));
  } catch {
    /* ignore */
  }
}

export function getCustomTemplates(): PdfTemplate[] {
  return readCustomCache();
}

/** Tous les modèles sélectionnables : intégrés + personnalisés. */
export function getAllTemplates(): PdfTemplate[] {
  return [...BUILTIN_TEMPLATES, ...readCustomCache()];
}

export function getActiveTemplateId(): PdfTemplateId | null {
  try {
    return typeof localStorage !== "undefined" ? localStorage.getItem(STORAGE_KEY) : null;
  } catch {
    return null;
  }
}

export function getActiveTemplate(): PdfTemplate {
  const id = getActiveTemplateId();
  // Fallback sur le modèle par défaut si l'id est introuvable.
  return getAllTemplates().find((t) => t.id === id) ?? DEFAULT_TEMPLATE;
}

export function setActiveTemplate(id: PdfTemplateId): void {
  try {
    localStorage.setItem(STORAGE_KEY, id);
  } catch {
    /* ignore */
  }
}
