/**
 * Configuration centralisée par type de document.
 * - QR Code : activable/désactivable par type (sécurité, traçabilité).
 * - Code-barres CODE128 : TOUJOURS affiché — il sert d'identifiant scannable
 *   du numéro de document même quand le QR est désactivé.
 */
export type FabsDocCode = "FC" | "PF" | "BC" | "BL" | "BR" | "AV" | "RP" | "BP" | "SP" | "IN";

/** 
 * Le QR code et l'UUID de vérification sont désormais activés 
 * UNIQUEMENT sur les factures (FC).
 */
const QR_BY_TYPE: Record<FabsDocCode, boolean> = {
  FC: true, // Facture
  PF: true, // Proforma
  BC: false, // Bon de commande
  BL: false, // Bon de livraison
  BR: false, // Bon de retour
  AV: false, // Avoir
  RP: false, // Reçu de paiement
  BP: false, // Bulletin de paie (interne)
  SP: false, // Bon spécimens
  IN: false, // Déclaration d'incident (interne)
};

export function shouldShowQr(type: FabsDocCode): boolean {
  return QR_BY_TYPE[type] ?? true;
}
