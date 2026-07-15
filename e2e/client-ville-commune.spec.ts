import { test, expect } from "@playwright/test";

/**
 * Vérifie l'ordre Ville puis Commune :
 *  - dans le panneau d'édition (Sheet)
 *  - dans la fiche client en lecture seule
 *
 * Prérequis : E2E_CLIENT_URL pointe vers /clients/<id>
 * et l'utilisateur est authentifié (via storageState ou credentials).
 */
const CLIENT_URL = process.env.E2E_CLIENT_URL ?? "/clients";

test.describe("Fiche client — ordre Ville / Commune", () => {
  test("lecture seule : Ville avant Commune", async ({ page }) => {
    await page.goto(CLIENT_URL);
    const card = page.getByTestId("client-readonly-card");
    await expect(card).toBeVisible();
    const ville = card.getByTestId("readonly-ville");
    const commune = card.getByTestId("readonly-commune");
    await expect(ville).toBeVisible();
    await expect(commune).toBeVisible();
    const villeBox = await ville.boundingBox();
    const communeBox = await commune.boundingBox();
    expect(villeBox && communeBox).toBeTruthy();
    if (Math.abs(villeBox!.y - communeBox!.y) < 4) {
      expect(villeBox!.x).toBeLessThan(communeBox!.x);
    } else {
      expect(villeBox!.y).toBeLessThan(communeBox!.y);
    }
  });

  test("panneau d'édition : Ville avant Commune", async ({ page }) => {
    await page.goto(CLIENT_URL);
    await page.getByRole("button", { name: /Modifier/i }).click();
    const panel = page.getByTestId("client-edit-panel");
    await expect(panel).toBeVisible();
    const villeInput = panel.getByTestId("input-ville");
    const communeInput = panel.getByTestId("input-commune");
    await expect(villeInput).toBeVisible();
    await expect(communeInput).toBeVisible();
    const v = await villeInput.boundingBox();
    const c = await communeInput.boundingBox();
    if (Math.abs(v!.y - c!.y) < 4) {
      expect(v!.x).toBeLessThan(c!.x);
    } else {
      expect(v!.y).toBeLessThan(c!.y);
    }
  });
});
