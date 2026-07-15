export type FNETemplate = "B2B" | "B2C" | "B2G" | "B2F";
export type FNEPaymentMethod = "cash" | "card" | "check" | "mobile-money" | "transfer" | "deferred";
export type FNEStatus = "pending" | "submitted" | "accepted" | "rejected" | "error";

export const STATUT_FNE_LABEL: Record<FNEStatus, string> = {
  pending: "En attente",
  submitted: "Soumise",
  accepted: "Certifiée",
  rejected: "Rejetée",
  error: "Erreur",
};
export const STATUT_FNE_COLOR: Record<FNEStatus, string> = {
  pending: "#F59E0B",
  submitted: "#0A2540",
  accepted: "#10B981",
  rejected: "#EF4444",
  error: "#EF4444",
};

export interface FNEInvoiceItem {
  reference: string;
  description: string;
  quantity: number;
  amount: number;
  discount?: number;
  measurementUnit?: string;
  taxes?: string[];
}

export interface FNEInvoicePayload {
  facture_id?: string | null;
  reference?: string;
  invoiceType?: "sale" | "purchase";
  paymentMethod?: string;
  template?: FNETemplate;
  clientNcc?: string | null;
  clientCompanyName: string;
  clientPhone?: string | null;
  clientEmail?: string | null;
  clientSellerName?: string | null;
  commercialMessage?: string | null;
  footer?: string | null;
  items: FNEInvoiceItem[];
  discount?: number;
}

export function mapPaymentMethod(raw: string | null | undefined): FNEPaymentMethod {
  const v = (raw ?? "").toString().trim().toLowerCase().replace(/\s+/g, "_");
  const map: Record<string, FNEPaymentMethod> = {
    especes: "cash",
    espèces: "cash",
    cash: "cash",
    liquide: "cash",
    mobile_money: "mobile-money",
    "mobile-money": "mobile-money",
    mobilemoney: "mobile-money",
    momo: "mobile-money",
    orange_money: "mobile-money",
    mtn_money: "mobile-money",
    wave: "mobile-money",
    carte_bancaire: "card",
    carte: "card",
    card: "card",
    visa: "card",
    mastercard: "card",
    cheque: "check",
    chèque: "check",
    check: "check",
    virement: "transfer",
    virement_bancaire: "transfer",
    transfer: "transfer",
    bank_transfer: "transfer",
    credit: "deferred",
    crédit: "deferred",
    a_credit: "deferred",
    differe: "deferred",
    différé: "deferred",
    deferred: "deferred",
  };
  return map[v] ?? "cash";
}

export function applyCorrections(invoice: FNEInvoicePayload, _companyNcc: string) {
  const corrections: string[] = [];
  invoice.items = invoice.items.map((it) => {
    if (!it.taxes || it.taxes.length === 0) {
      corrections.push(`[C4] Ligne "${it.description}" : taxes par défaut ["TVA"]`);
      return { ...it, taxes: ["TVA"] };
    }
    return it;
  });
  if (invoice.template === "B2B" && !invoice.clientNcc) {
    corrections.push(`[C2] B2B sans NCC client → fallback B2C`);
    invoice.template = "B2C";
  }
  const pm = mapPaymentMethod(invoice.paymentMethod);
  if (pm !== invoice.paymentMethod) {
    corrections.push(`[C3] paymentMethod normalisé : ${invoice.paymentMethod} → ${pm}`);
    invoice.paymentMethod = pm;
  }
  return corrections;
}
