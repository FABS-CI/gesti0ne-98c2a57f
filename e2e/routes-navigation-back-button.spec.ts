import { test, expect } from "@playwright/test";
import { signInAsTestUser } from "./helpers/auth";
import {
  ensureAtLeastOneExercice,
  ensureAtLeastOneLivraisonSuivi,
} from "./helpers/fixtures-nav";

/**
 * Vérifie que le bouton « Retour » du navigateur conserve et revalide
 * le `search` reconstruit lors de la navigation :
 *  - liste → détail → retour → liste (search identique)
 *  - liste → détail → détail sous-page → retour → détail (search valide)
 */

async function expectNoCrash(page: import("@playwright/test").Page) {
  const crashed = await page
    .getByText(/quelque chose s'est mal passé|something went wrong/i)
    .isVisible()
    .catch(() => false);
  expect(crashed).toBe(false);
}

test.describe("Bouton retour navigateur — search revalidé", () => {
  test.beforeAll(async () => {
    await ensureAtLeastOneExercice();
    await ensureAtLeastOneLivraisonSuivi();
  });

  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("Exercices → Comparatif → back : URL /exercices restaurée sans crash", async ({ page }) => {
    await page.goto("/exercices");
    const urlAvant = page.url();
    await page.getByRole("link", { name: /^comparatif$/i }).click();
    await expect(page).toHaveURL(/\/exercices\/comparatif/);

    await page.goBack();
    await expect(page).toHaveURL(urlAvant);
    await expectNoCrash(page);

    // Forward re-valide aussi le search de comparatif (defaults).
    await page.goForward();
    await expect(page).toHaveURL(/\/exercices\/comparatif/);
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  });

  test("Livraison-suivi → détail → back : liste restaurée + search intact", async ({ page }) => {
    await page.goto("/livraison-suivi");
    const urlListe = page.url();

    const firstRef = page.locator('a[href^="/livraison-suivi/"]').first();
    await expect(firstRef).toBeVisible();
    const hrefDetail = await firstRef.getAttribute("href");
    await firstRef.click();
    await expect(page).toHaveURL(new RegExp(hrefDetail!.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));

    await page.goBack();
    await expect(page).toHaveURL(urlListe);
    await expectNoCrash(page);

    // Forward → détail re-hydraté avec un search valide.
    await page.goForward();
    await expect(page).toHaveURL(new RegExp(hrefDetail!.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    await expectNoCrash(page);
  });

  test("Détail livraison → Remise → back : détail restauré", async ({ page }) => {
    await page.goto("/livraison-suivi");
    const firstRef = page.locator('a[href^="/livraison-suivi/"]').first();
    await expect(firstRef).toBeVisible();
    await firstRef.click();
    const urlDetail = page.url();

    const btnRemise = page.getByRole("link", { name: /remise (au livreur|au transporteur)/i });
    const hasRemise = await btnRemise.isVisible().catch(() => false);
    test.skip(!hasRemise, "Fixture sans étape remise disponible.");
    await btnRemise.click();
    await expect(page).toHaveURL(/\/livraison-suivi\/[^/]+\/remise/);

    await page.goBack();
    await expect(page).toHaveURL(urlDetail);
    await expectNoCrash(page);
  });
});