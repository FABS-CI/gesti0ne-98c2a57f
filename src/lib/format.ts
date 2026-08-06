import { format as dateFnsFormat } from "date-fns";

export function formatFCFA(amount: number | null | undefined, withSuffix = true): string {
  if (amount == null || isNaN(Number(amount))) return "—";
  const formatted = Number(amount)
    .toLocaleString("fr-FR", { maximumFractionDigits: 0 })
    .replace(/[\u00A0\u202F,]/g, " ");
  return withSuffix ? `${formatted} FCFA` : formatted;
}

export function formatFCFACompact(amount: number | null | undefined): string {
  if (amount == null || isNaN(Number(amount))) return "—";
  const n = Number(amount);
  if (Math.abs(n) >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(".", ",")} M`;
  if (Math.abs(n) >= 1_000) return `${(n / 1_000).toFixed(0)} K`;
  return String(n);
}

/**
 * Formate une date au format standard ERP : JJ/MM/AAAA
 */
export function formatDate(date: string | Date | null | undefined): string {
  if (!date) return "—";
  const d = typeof date === "string" ? new Date(date) : date;
  if (isNaN(d.getTime())) return String(date);
  return dateFnsFormat(d, "dd/MM/yyyy");
}

/**
 * Formate une date et heure au format standard ERP : JJ/MM/AAAA HH:mm
 */
export function formatDateTime(date: string | Date | null | undefined): string {
  if (!date) return "—";
  const d = typeof date === "string" ? new Date(date) : date;
  if (isNaN(d.getTime())) return String(date);
  return dateFnsFormat(d, "dd/MM/yyyy HH:mm");
}

