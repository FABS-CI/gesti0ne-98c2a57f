import { CommercialDocument } from "./commercial-document";
import { StatementDocument } from "./statement-document";
import { ReceiptDocument, type ReceiptData } from "./receipt-document";
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
    remiseGlobale: data.remiseGlobale || data.remise || 0,
    remiseGlobalePct: data.remiseGlobalePct || data.remisePct || 0,
    tva: data.tva || 0,
    totalAPayer: data.totalTTC || data.montantHT || data.totalVente || 0,
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
 * Adaptateur pour le Bon de Réception (Approvisionnement)
 */
export async function generateUnifiedAchatPDF(
  data: DataBase
): Promise<Blob> {
  const docBase = {
    id: data.br_id || data.id || "achat-id",
    type: "Bon de Réception",
    reference: data.reference,
    date: data.date,
    client: {
      nom: data.clientNom || "",
      ville: data.villeClient || "",
      adresse: data.adresseClient || "",
      representant: data.representant || "",
      telephone: data.clientTel || "",
      email: data.emailClient || "",
      code: data.codeClient || "",
    }
  };

  const totals = {
    sousTotal: data.totalVente || 0,
    remiseLignes: data.remiseLigneTotal || 0,
    remiseLignesPct: data.remisePct || 0,
    remiseGlobale: data.remiseGlobale || 0,
    remiseGlobalePct: data.remiseGlobalePct || 0,
    tva: data.tva || 0,
    totalAPayer: data.totalTTC || data.montantHT || data.totalVente || 0,
    montantLettres: (data as any).montantLettres || (data as any).montantEnLettres || numberToLetters(data.totalTTC || data.montantHT || 0),
  };

  const doc = new CommercialDocument(docBase, totals);
  await doc.init();
  
  (doc.data as any).lignes = data.lignes || [];
  (doc.data as any).notes = data.notes;

  // Détection du mode de remise :
  // Si remise sur lignes > 0, on affiche la colonne Remise (%)
  const discountMode = (totals.remiseLignes && totals.remiseLignes > 0) ? 'A' : 
                      (totals.remiseGlobale && totals.remiseGlobale > 0) ? 'B' : 'NONE';
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
    reference: data.reference || "RELEVÉ",
    date: new Date().toISOString(), // On garde l'ISO ici, il sera formaté par BaseDocument.drawHeader

    client: {
      nom: data.client?.nom || "",
      code: data.client?.reference || "",
      telephone: data.client?.telephone || "",
      representant: data.client?.representant || "",
      ville: data.client?.ville || "",
    }
  };

  const doc = new StatementDocument(docBase, {} as any);
  await doc.init();
  await doc.drawContent(data);
  return await doc.getBlob();
}

/**
 * Génère un reçu de paiement avec le nouveau moteur ReceiptDocument
 */
export async function generateUnifiedReceiptPDF(data: DataBase): Promise<Blob> {
  const docBase = {
    id: data.id || "receipt-id",
    type: "Reçu de Paiement",
    reference: data.reference,
    date: data.date,
    client: {
      nom: data.clientNom || "",
      ville: data.villeClient || "",
      adresse: data.adresseClient || "",
      representant: data.representant || "",
      telephone: data.clientTel || "",
      code: data.codeClient || "",
    }
  };

  const receiptData: ReceiptData = {
    paymentNumber: data.reference,
    paymentDate: data.date,
    customerName: data.clientNom || "",
    customerCity: data.villeClient || undefined,
    customerRep: data.representant || undefined,
    customerPhone: data.clientTel || undefined,
    invoiceNumber: data.factureReference || "—",
    invoiceTotal: Number(data.factureMontantTotal ?? 0),
    balanceBefore: data.factureMontantPayeAvant !== null && data.factureMontantTotal !== null
      ? Number(data.factureMontantTotal) - Number(data.factureMontantPayeAvant)
      : Number(data.totalTTC || 0), // Fallback if data is missing
    amountPaid: Number(data.totalTTC || 0),
    balanceAfter: 0, // Calculated below
    paymentMethod: data.modePaiement || "Espèces",
    paymentReference: (data as any).num_transaction || (data as any).paymentReference || undefined,
    notes: data.notes || undefined,
  };


  // Re-calculate balance after based on balance before and amount paid
  receiptData.balanceAfter = Math.max(0, receiptData.balanceBefore - receiptData.amountPaid);

  const doc = new ReceiptDocument(docBase, receiptData);
  await doc.init();
  await doc.drawContent();
  return await doc.getBlob();
}

