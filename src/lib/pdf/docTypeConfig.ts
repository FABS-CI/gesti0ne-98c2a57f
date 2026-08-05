/**
 * Configuration centralisée par type de document.
 * - QR Code : activable/désactivable par type (sécurité, traçabilité).
 * - Code-barres CODE128 : TOUJOURS affiché — il sert d'identifiant scannable
 *   du numéro de document même quand le QR est désactivé.
 */
export type FabsDocCode = "FC" | "PF" | "BC" | "BL" | "BR" | "AV" | "RP" | "BP" | "SP" | "IN";

/** 
 * Le QR code est désormais activé pour tous les documents commerciaux 
 * pour permettre la vérification d'authenticité via UUID.
 */
const QR_BY_TYPE: Record<FabsDocCode, boolean> = {
  FC: true, // Facture
  PF: true, // Proforma
  BC: true, // Bon de commande
  BL: true, // Bon de livraison
  BR: true, // Bon de retour
  AV: true, // Avoir
  RP: true, // Reçu de paiement
  BP: false, // Bulletin de paie (interne)
  SP: true, // Bon spécimens
  IN: false, // Déclaration d'incident (interne)
};

export function shouldShowQr(type: FabsDocCode): boolean {
  return QR_BY_TYPE[type] ?? true;
}
