/**
 * Configuration centralisée par type de document.
 * - QR Code : activable/désactivable par type (sécurité, traçabilité).
 * - Code-barres CODE128 : TOUJOURS affiché — il sert d'identifiant scannable
 *   du numéro de document même quand le QR est désactivé.
 */
export type FabsDocCode = "FAC" | "PRO" | "CMD" | "BL" | "RET" | "AVO" | "RP" | "BS" | "BP" | "IN";

/** 
 * Le QR code et l'UUID de vérification sont désormais activés 
 * UNIQUEMENT sur les factures (FAC).
 */
const QR_BY_TYPE: Record<string, boolean> = {
  FAC: true,  // Facture
  PRO: false, // Proforma
  CMD: false, // Bon de commande
  BL: false,  // Bon de livraison
  RET: false, // Bon de retour
  AVO: false, // Avoir
  RP: false,  // Reçu de paiement
  BS: false,  // Bon spécimens
  BP: false,  // Bulletin de paie (interne)
  IN: false,  // Déclaration d'incident (interne)
};

export function shouldShowQr(prefix: string): boolean {
  return QR_BY_TYPE[prefix] ?? false; // Par défaut false si inconnu
}
