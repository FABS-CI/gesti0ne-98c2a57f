/**
 * Le QR code et l'UUID de vérification sont désormais activés
 * UNIQUEMENT sur les factures (FAC).
 */
const QR_BY_TYPE = {
    FAC: true, // Facture
    FC: true, // Alias Facture
    PRO: false, // Proforma
    PF: false, // Alias Proforma
    CMD: false, // Bon de commande
    BC: false, // Alias Bon de commande
    BL: false, // Bon de livraison
    RET: false, // Bon de retour
    BR: false, // Alias Bon de retour
    AVO: false, // Avoir
    AV: false, // Alias Avoir
    RP: false, // Reçu de paiement
    BS: false, // Bon spécimens
    SP: false, // Alias Spécimens
    BP: false, // Bulletin de paie (interne)
    IN: false, // Déclaration d'incident (interne)
};
export function shouldShowQr(prefix) {
    return QR_BY_TYPE[prefix] ?? false; // Par défaut false si inconnu
}
