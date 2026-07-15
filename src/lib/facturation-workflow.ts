/**
 * Audit workflow: Facturation → Paiements → Comptes clients.
 * Fonctions pures qui reflètent la logique attendue en base pour permettre
 * des tests de non-régression sur les KPI après chaque étape.
 */
import { computeRecap, type RecapLine } from "./paiement-recap";

export type Facture = { reference: string; montant_ttc: number; encaisse: number };

export type CompteClientKPI = {
  total_facture: number;
  total_encaisse: number;
  solde_du: number;
  taux_recouvrement: number; // 0..1
  nb_factures_ouvertes: number;
};

export function factureSolde(f: Facture): number {
  return Math.max(0, f.montant_ttc - f.encaisse);
}

/** Applique un paiement à une facture et renvoie la nouvelle facture + le récap. */
export function appliquerPaiement(
  facture: Facture,
  montantRecu: number,
): { facture: Facture; recap: RecapLine } {
  const solde = factureSolde(facture);
  const recap = computeRecap(facture.reference, solde, montantRecu);
  return {
    facture: { ...facture, encaisse: facture.encaisse + recap.montant_impute },
    recap,
  };
}

/** Annule un paiement: retire le montant imputé du cumul encaissé. */
export function annulerPaiement(facture: Facture, montantAnnule: number): Facture {
  const encaisse = Math.max(0, facture.encaisse - Math.max(0, montantAnnule));
  return { ...facture, encaisse };
}

export function computeCompteClientKPI(factures: Facture[]): CompteClientKPI {
  const total_facture = factures.reduce((s, f) => s + f.montant_ttc, 0);
  const total_encaisse = factures.reduce((s, f) => s + Math.min(f.encaisse, f.montant_ttc), 0);
  const solde_du = factures.reduce((s, f) => s + factureSolde(f), 0);
  const nb_factures_ouvertes = factures.filter((f) => factureSolde(f) > 0).length;
  const taux_recouvrement = total_facture > 0 ? total_encaisse / total_facture : 0;
  return {
    total_facture,
    total_encaisse,
    solde_du,
    taux_recouvrement,
    nb_factures_ouvertes,
  };
}
