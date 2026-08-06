import { createFileRoute, Navigate } from "@tanstack/react-router";

/**
 * ============================================================================
 * AUDIT COMPLET DU WORKFLOW MÉTIER (LOGIQUE, STOCKS, COMPTABILITÉ)
 * ============================================================================
 * 
 * 1. CARTOGRAPHIE DU WORKFLOW
 * ---------------------------
 * Client -> [PROFORMA] -> COMMANDE (En attente) -> [VALIDATION] 
 *   -> FACTURATION (Génération FAC + Écritures Compta)
 *   -> LOGISTIQUE (Génération BL + Réservation/Mouvement Stock)
 *   -> COLISAGE (Préparation + Étiquetage)
 *   -> LIVRAISON (Tournée + Expédition + Remise)
 *   -> PAIEMENT (Imputation + Mise à jour Solde)
 * 
 * 2. LOGIQUE MÉTIER & POINTS CRITIQUES
 * ------------------------------------
 * - PRÉREQUIS : Tout document doit être rattaché à un Client et un Exercice ouvert.
 * - VALIDATION : Déclencheur unique (RPC: valider_commande).
 * - CALCULS :
 *   * HT Brut = Somme(Qte * PU)
 *   * HT Net = HT Brut - Remises Lignes - Remise Globale
 *   * TTC = HT Net + TVA (calculée sur le net)
 * 
 * 3. MOUVEMENTS DE STOCK (DÉSTOCKAGE)
 * -----------------------------------
 * - MOMENT : Uniquement lors de la VALIDATION de la commande.
 * - FONCTION : rpc.valider_commande -> rpc.ajuster_stock_depot.
 * - TABLES : stocks_depots (quantite), stock_mouvements (historique).
 * - SÉCURITÉ : Un BL/Facture ne peut être généré qu'après déstockage réussi.
 * 
 * 4. ÉCRITURES COMPTABLES
 * -----------------------
 * - MOMENT : Génération de la Facture (Automatique après validation).
 * - JOURNAUX : Ventes (VT), Banque (BQ) ou Caisse (CS) pour les paiements.
 * - COMPTES : 411 (Client) Debit / 701 (Ventes) Credit / 443 (TVA) Credit.
 * 
 * 5. DROITS & ACCÈS (RBAC v3)
 * ---------------------------
 * - ADMINISTRATEUR : Accès total, suppressions définitives, audit.
 * - COMMERCIAL : Création/Modification (avant validation).
 * - MAGASINIER : Colisage, Inventaires, Réceptions.
 * - LIVREUR : Suivi des tournées, validation BL.
 * - COMPTABILITÉ : Facturation, Paiements, États financiers.
 */

export const Route = createFileRoute("/")({
  component: () => {
    // Redirection automatique vers le tableau de bord en production
    return <Navigate to="/dashboard" />;
  },
});
