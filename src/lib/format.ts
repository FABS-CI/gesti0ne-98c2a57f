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
