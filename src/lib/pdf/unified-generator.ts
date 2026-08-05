import { CommercialDocument } from "./commercial-document";
import { StatementDocument } from "./statement-document";
import { resolveDiscountMode, type DocTotals as DataTotals } from "./enrich-lignes";
import type { DocBase as DataBase } from "./fabsTemplates";
import { numberToLetters } from "./number-to-letters";

/**
 * Adaptateur pour brancher le nouveau moteur BaseDocument sur les fonctions legacy
 */
export async function generateUnifiedCommercialPDF(
  type: "Facture" | "Proforma" | "Commande" | "Bon de Livraison" | "Avoir" | "Spécimens" | "Bon de Retour",
  data: DataBase
): Promise<Blob> {
  const docBase = {
    id: (data as any).id || (data as any).facture_id || (data as any).commande_id || (data as any).proforma_id || (data as any).bl_id || (data as any).br_id || "verification-only",
    type: type,
    reference: data.reference,
    date: data.date,
    commercial: (data as any).commercialNom || (data as any).representant || "",
    client: {
      nom: data.clientNom || "",
      ville: data.villeClient || "",
      adresse: data.adresseClient || "",
      representant: data.representant || "",
      telephone: data.clientTel || data.representantTel || "",
      email: data.emailClient || "",
      code: data.codeClient || "",
    }
  };

  const totals = {
    sousTotal: data.totalVente || 0,
    remiseLignes: data.remiseLigneTotal || 0,
    remiseGlobale: data.remiseGlobale || 0,
    remiseGlobalePct: data.remiseGlobalePct || 0,
    tva: data.tva || 0,
    totalAPayer: data.totalTTC || data.montantHT || 0,
    montantLettres: (data as any).montantLettres || (data as any).montantEnLettres || numberToLetters(data.totalTTC || data.montantHT || 0),
  };

  const doc = new CommercialDocument(docBase, totals);
  await doc.init();
  
  // Injecter les données spécifiques FABS
  (doc.data as any).lignes = data.lignes || [];
  (doc.data as any).soldeDu = (data as any).soldeDu || (data as any).resteDu || 0;

  // Détection du mode de remise pour le tableau
  const discountMode = resolveDiscountMode({
    remiseLigneTotal: totals.remiseLignes,
    remiseGlobale: totals.remiseGlobale
  } as any);
  doc.setDiscountMode(discountMode);

  await doc.drawContent();
  return await doc.getBlob();
}

/**
 * Génère un relevé de compte avec le nouveau moteur
 */
export async function generateUnifiedStatementPDF(data: any): Promise<Blob> {
  const docBase = {
    id: data.client_id || "statement",
    type: "Relevé de Compte",
    reference: data.reference || `RLV-${new Date().getTime()}`,
    date: new Date().toISOString(),
    client: {
      nom: data.client?.nom || "",
      code: data.client?.reference || "",
      telephone: data.client?.telephone || "",
    }
  };

  const doc = new StatementDocument(docBase, {} as any);
  await doc.init();
  await doc.drawContent(data);
  return await doc.getBlob();
}
