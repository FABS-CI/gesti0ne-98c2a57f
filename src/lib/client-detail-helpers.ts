import type { ClientRelations } from "@/lib/clients-api";
import type { EtatCompteLigne } from "@/lib/pdf/fabsTemplates";

export function frDate(d: string | null | undefined): string {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("fr-FR");
}

export function frDateTime(d: string): string {
  return new Date(d).toLocaleString("fr-FR");
}

export const ACTION_LABEL: Record<string, string> = {
  INSERT: "Création",
  UPDATE: "Modification",
  DELETE: "Suppression",
};

export const ACTION_VARIANT: Record<string, "default" | "secondary" | "destructive"> = {
  INSERT: "default",
  UPDATE: "secondary",
  DELETE: "destructive",
};

export function buildEtatCompteLignes(rel: ClientRelations): EtatCompteLigne[] {
  const lignes: EtatCompteLigne[] = [
    ...rel.factures.map((f) => ({
      date: f.date_facture,
      type: "Facture",
      reference: f.reference,
      debit: Number(f.montant_total),
    })),
    ...rel.paiements
      .filter((p) => p.statut === "valide")
      .map((p) => ({
        date: p.date_paiement,
        type: `Règlement (${p.mode_paiement})`,
        reference: p.reference,
        credit: Number(p.montant),
      })),
  ];
  return lignes.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
}

export function buildMonthlyStats(factures: ClientRelations["factures"]) {
  const buckets = new Map<string, { mois: string; ca: number; paye: number }>();
  const now = new Date();
  for (let i = 11; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    buckets.set(key, {
      mois: d.toLocaleDateString("fr-FR", { month: "short" }),
      ca: 0,
      paye: 0,
    });
  }
  for (const f of factures) {
    const d = new Date(f.date_facture);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    const b = buckets.get(key);
    if (b) {
      b.ca += Number(f.montant_total);
      b.paye += Number(f.montant_paye);
    }
  }
  return Array.from(buckets.values());
}
