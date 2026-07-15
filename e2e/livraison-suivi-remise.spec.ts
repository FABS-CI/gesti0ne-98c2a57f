import { test, expect } from "@playwright/test";
import { signInAsTestUser, gotoRemise } from "./helpers/auth";
import {
  createRemiseFixture,
  deleteRemiseFixture,
  type RemiseFixture,
} from "./helpers/fixtures";

/**
 * Vérifie que le bouton « Valider l'étape » de la page Remise ne s'active
 * que lorsque commande + colis + livreur sont préchargés.
 *
 * Deux fixtures :
 *   - complete   → bouton visible ET activé
 *   - incomplete → bouton visible mais désactivé + alerte affichée
 */
test.describe("/livraison-suivi/$commandeRef/remise", () => {
  let complete: RemiseFixture;
  let incomplete: RemiseFixture;

  test.beforeAll(async () => {
    complete = await createRemiseFixture({ withColis: true, withLivreur: true });
    incomplete = await createRemiseFixture({ withColis: true, withLivreur: false });
  });

  test.afterAll(async () => {
    if (complete) await deleteRemiseFixture(complete);
    if (incomplete) await deleteRemiseFixture(incomplete);
  });

  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("bouton activé quand commande + colis + livreur sont préchargés", async ({ page }) => {
    await gotoRemise(page, complete.commandeRef);

    await expect(page.getByText("Informations de la commande")).toBeVisible();
    await expect(page.getByText("Informations des colis")).toBeVisible();
    await expect(page.getByText("Informations du livreur")).toBeVisible();

    const btn = page.getByRole("button", { name: /Valider l'étape/i });
    await expect(btn).toBeVisible();
    await expect(btn).toBeEnabled();

    await expect(page.getByText("Informations manquantes")).toHaveCount(0);
  });

  test("bouton désactivé + alerte quand le livreur n'est pas préchargé", async ({ page }) => {
    await gotoRemise(page, incomplete.commandeRef);

    await expect(page.getByText("Informations manquantes")).toBeVisible();
    const btn = page.getByRole("button", { name: /Valider l'étape/i });
    await expect(btn).toBeVisible();
    await expect(btn).toBeDisabled();
  });
});