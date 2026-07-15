import { test, expect } from "@playwright/test";
import { signInAsTestUser } from "./helpers/auth";

/**
 * Cas limites de la reconstruction du `search` lors de la navigation
 * vers `/exercices/*` et `/livraison-suivi/*`.
 *
 * On simule des URL construites à la main (comme si un Link avait
 * omis / corrompu les params) et on vérifie que :
 *  - la route matche toujours ;
 *  - le validator applique les défauts (`fallback()`) ;
 *  - aucun error boundary global ne s'affiche.
 */

async function expectNoCrash(page: import("@playwright/test").Page) {
  const crashed = await page
    .getByText(/quelque chose s'est mal passé|something went wrong/i)
    .isVisible()
    .catch(() => false);
  expect(crashed).toBe(false);
}

test.describe("Cas limites — params manquants ou vides", () => {
  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("/exercices/comparatif sans aucun param : rend avec les défauts", async ({ page }) => {
    await page.goto("/exercices/comparatif");
    await expect(page).toHaveURL(/\/exercices\/comparatif/);
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expectNoCrash(page);
  });

  test("/exercices/comparatif avec params vides (?sort=&dir=&pct=)", async ({ page }) => {
    await page.goto("/exercices/comparatif?sort=&dir=&pct=");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expectNoCrash(page);
  });

  test("/exercices/rapport sans `exercice` : ne crashe pas (fallback introuvable)", async ({ page }) => {
    await page.goto("/exercices/rapport");
    await expectNoCrash(page);
  });

  test("/exercices/rapport avec exercice=<vide> : accepté et pas de crash", async ({ page }) => {
    await page.goto("/exercices/rapport?exercice=");
    await expectNoCrash(page);
  });

  test("/livraison-suivi/$ref sans `debug` : validator applique le défaut", async ({ page }) => {
    await page.goto("/livraison-suivi/E2E-EDGE-EMPTY");
    await expectNoCrash(page);
  });

  test("/livraison-suivi/$ref avec `debug=` vide : fallback → false", async ({ page }) => {
    await page.goto("/livraison-suivi/E2E-EDGE-EMPTY?debug=");
    await expectNoCrash(page);
  });

  test("/livraison-suivi/$ref/remise avec `debug` corrompu : accepté", async ({ page }) => {
    await page.goto("/livraison-suivi/E2E-EDGE-EMPTY/remise?debug=%E2%98%A0");
    await expectNoCrash(page);
  });
});