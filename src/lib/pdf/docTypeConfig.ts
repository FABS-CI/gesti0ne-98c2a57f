/**
 * Configuration centralisée par type de document.
 * - QR Code : activable/désactivable par type (sécurité, traçabilité).
 * - Code-barres CODE128 : TOUJOURS affiché — il sert d'identifiant scannable
 *   du numéro de document même quand le QR est désactivé.
 */
export type FabsDocCode = "FAC" | "PRO" | "CMD" | "BL" | "RET" | "AVO" | "RP" | "BS" | "BP" | "IN";

/** 
 * Le QR code et l'UUID de vérification sont activés 
 * pour les factures (FAC), bons de livraison (BL) et reçus de paiement (RP).
 */
const QR_BY_TYPE: Record<string, boolean> = {
  FAC: true,  // Facture
  FC: true,   // Alias Facture
  PRO: false, // Proforma
  PF: false,  // Alias Proforma
  CMD: false, // Bon de commande
  BC: false,  // Alias Bon de commande
  BL: true,  // Bon de livraison
  RET: false, // Bon de retour
  ACH: false, // Achats (Bon de Réception)
  BR: false,  // Alias Bon de Réception
  AVO: false, // Avoir
  AV: false,  // Alias Avoir
  RP: true,   // Reçu de paiement (Activé pour traçabilité des encaissements)
  PAI: true,  // Alias Paiement (Activé pour traçabilité)
  BS: false,  // Bon spécimens
  SP: false,  // Alias Spécimens
  BP: false,  // Bulletin de paie (interne)
  IN: false,  // Déclaration d'incident (interne)
};

export function shouldShowQr(prefix: string): boolean {
  return QR_BY_TYPE[prefix] ?? false; // Par défaut false si inconnu
}
