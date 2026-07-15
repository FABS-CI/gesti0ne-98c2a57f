import { test, expect } from "@playwright/test";
import {
  hasAuthSession,
  resetFixtures,
  setFacturePaye,
  getFactureFixture,
} from "./fixtures/supabase";

test.describe("Trigger statut facture (payee / partielle / impayee)", () => {
  test.skip(!hasAuthSession, "Lovable-injected Supabase session required");

  test.beforeEach(async () => {
    await resetFixtures();
  });

  test("impayee -> partielle -> payee -> impayee selon montant_paye", async () => {
    // Etat initial
    let f = await getFactureFixture();
    expect(f.statut).toBe("impayee");
    expect(Number(f.montant_paye)).toBe(0);

    // Paiement partiel
    expect(await setFacturePaye(5000)).toBe("partielle");
    f = await getFactureFixture();
    expect(f.statut).toBe("partielle");
    expect(Number(f.montant_paye)).toBe(5000);

    // Paiement complet
    expect(await setFacturePaye(10000)).toBe("payee");
    f = await getFactureFixture();
    expect(f.statut).toBe("payee");

    // Sur-paiement -> reste payee
    expect(await setFacturePaye(12000)).toBe("payee");

    // Retour à zéro -> impayee
    expect(await setFacturePaye(0)).toBe("impayee");
  });
});