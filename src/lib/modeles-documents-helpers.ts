import { DEFAULT_TEMPLATE, type PdfTemplate, type RGB } from "@/lib/pdf/pdfConfig";
import type { DocType } from "@/lib/document-settings-api";

export const rgb = (c: readonly number[]) => `rgb(${c[0]}, ${c[1]}, ${c[2]})`;
export const toHex = (c: RGB) =>
  "#" + c.map((n) => Math.max(0, Math.min(255, n)).toString(16).padStart(2, "0")).join("");
export const fromHex = (h: string): RGB => {
  const m = /^#?([0-9a-f]{6})$/i.exec(h.trim());
  if (!m) return [0, 0, 0];
  const v = m[1];
  return [parseInt(v.slice(0, 2), 16), parseInt(v.slice(2, 4), 16), parseInt(v.slice(4, 6), 16)];
};

export type FormState = Omit<PdfTemplate, "id" | "custom">;

export const blankForm = (): FormState => ({
  label: "Mon modèle",
  description: "Modèle personnalisé",
  font: "helvetica",
  headerVariant: "classique",
  headerBg: DEFAULT_TEMPLATE.headerBg,
  companyColor: [255, 255, 255],
  titleColor: [255, 98, 0],
  tableHeadFill: [10, 37, 64],
  accent: [255, 98, 0],
  totalBoxed: false,
  headerHeight: 28,
  bodyTop: 38,
  footerNote: "",
});

export const DOC_TYPES: [DocType, string][] = [
  ["facture", "Factures"],
  ["proforma", "Proformas"],
  ["bon_commande", "Bons de commande"],
  ["bon_livraison", "Bons de livraison"],
  ["bon_retour", "Bons de retour"],
  ["avoir", "Avoirs"],
  ["recu", "Reçus"],
  ["etat_compte", "États de compte"],
  ["bulletin", "Bulletins de paie"],
];
