import { describe, it, expect } from "vitest";
import {
  appliquerPaiement,
  annulerPaiement,
  computeCompteClientKPI,
  factureSolde,
  type Facture,
} from "./facturation-workflow";

describe("Audit workflow Facturation → Paiements → Comptes clients", () => {
  const factures: Facture[] = [
    { reference: "F001", montant_ttc: 1000, encaisse: 0 },
    { reference: "F002", montant_ttc: 500, encaisse: 0 },
  ];

  it("étape 1 — KPI initiaux après facturation", () => {
    const k = computeCompteClientKPI(factures);
    expect(k.total_facture).toBe(1500);
    expect(k.total_encaisse).toBe(0);
    expect(k.solde_du).toBe(1500);
    expect(k.nb_factures_ouvertes).toBe(2);
    expect(k.taux_recouvrement).toBe(0);
  });

  it("étape 2 — paiement partiel: KPI recalculés", () => {
    const { facture, recap } = appliquerPaiement(factures[0], 400);
    expect(recap).toEqual({
      reference: "F001",
      reste_avant: 1000,
      montant_impute: 400,
      reste_apres: 600,
    });
    const k = computeCompteClientKPI([facture, factures[1]]);
    expect(k.total_encaisse).toBe(400);
    expect(k.solde_du).toBe(1100);
    expect(k.nb_factures_ouvertes).toBe(2);
    expect(k.taux_recouvrement).toBeCloseTo(400 / 1500);
  });

  it("étape 3 — sur-paiement plafonné au solde de la facture", () => {
    const { facture, recap } = appliquerPaiement(factures[1], 999);
    expect(recap.montant_impute).toBe(500);
    expect(factureSolde(facture)).toBe(0);
  });

  it("étape 4 — annulation d’un paiement: KPI reviennent à l’état antérieur", () => {
    const { facture: f1 } = appliquerPaiement(factures[0], 400);
    const rollback = annulerPaiement(f1, 400);
    const k = computeCompteClientKPI([rollback, factures[1]]);
    expect(k.total_encaisse).toBe(0);
    expect(k.solde_du).toBe(1500);
  });

  it("non-régression — annulation partielle", () => {
    const { facture: f1 } = appliquerPaiement(factures[0], 400);
    const partial = annulerPaiement(f1, 150);
    expect(partial.encaisse).toBe(250);
    expect(factureSolde(partial)).toBe(750);
  });
});
