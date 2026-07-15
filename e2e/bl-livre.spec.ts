import { test, expect } from "@playwright/test";
import {
  hasAuthSession,
  resetFixtures,
  setColisLivre,
  getBlFixture,
} from "./fixtures/supabase";

test.describe("Trigger BL livré quand tous les colis passent à 'livre'", () => {
  test.skip(!hasAuthSession, "Lovable-injected Supabase session required");

  test.beforeEach(async () => {
    await resetFixtures();
  });

  test("BL passe à livre + date_livraison renseignée dès que tous les colis sont livrés", async () => {
    let bl = await getBlFixture();
    expect(bl.statut).toBe("a_preparer");
    expect(bl.date_livraison).toBeNull();

    // Un seul colis livré -> BL doit rester en attente
    await setColisLivre(1);
    bl = await getBlFixture();
    expect(bl.statut).not.toBe("livre");
    expect(bl.date_livraison).toBeNull();

    // Dernier colis livré -> BL doit basculer à livre
    await setColisLivre(2);
    bl = await getBlFixture();
    expect(bl.statut).toBe("livre");
    expect(bl.date_livraison).not.toBeNull();
  });
});