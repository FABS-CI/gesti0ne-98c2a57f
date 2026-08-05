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
  FC: true,   // Alias Facture
  PRO: true,  // Proforma
  PF: true,   // Alias Proforma
  CMD: true,  // Bon de commande
  BC: true,   // Alias Bon de commande
  BL: true,   // Bon de livraison
  RET: true,  // Bon de retour
  BR: true,   // Alias Bon de retour
  AVO: true,  // Avoir
  AV: true,   // Alias Avoir
  RP: true,   // Reçu de paiement
  BS: true,   // Bon spécimens
  SP: true,   // Alias Spécimens
  BP: true,   // Bulletin de paie (interne)
  IN: true,   // Déclaration d'incident (interne)
};

export function shouldShowQr(prefix: string): boolean {
  return QR_BY_TYPE[prefix] ?? false; // Par défaut false si inconnu
}
