import { test, expect } from "./fixtures/base";
import {
  hasAuthSession,
  setFactureStatut,
  FIXTURE_IDS,
} from "./fixtures/supabase";

/**
 * Régression visuelle des badges de statut (factures + BL).
 * Un snapshot par (projet × statut) est stocké sous e2e/__screenshots__.
 * Les diffs sont téléversés en artefacts CI en cas d'échec.
 */
test.describe("Régression visuelle — badges statut", () => {
  test.skip(!hasAuthSession, "Lovable-injected Supabase session required");

  for (const statut of ["impayee", "partielle", "payee", "annulee", "avoir"] as const) {
    test(`badge facture ${statut}`, async ({ page, baseURL }, testInfo) => {
      await setFactureStatut(statut);
      const base = baseURL ?? "http://localhost:8080";
      await page.goto(`${base}/factures/${FIXTURE_IDS.facture}`, {
        waitUntil: "domcontentloaded",
      });
      const badge = page
        .locator('[class*="badge"], .badge, span')
        .filter({ hasText: /^(Annulée|Avoir|Payée|Partielle|Impayée)$/ })
        .first();
      await expect(badge).toBeVisible();
      await expect(badge).toHaveScreenshot(
        `facture-${statut}-${testInfo.project.name}.png`,
        { maxDiffPixelRatio: 0.02 },
      );
    });
  }

  test("badge BL (état courant fixture)", async ({ page, baseURL }, testInfo) => {
    const base = baseURL ?? "http://localhost:8080";
    await page.goto(`${base}/bons-livraison/${FIXTURE_IDS.bl}`, {
      waitUntil: "domcontentloaded",
    });
    const badge = page
      .locator('[class*="badge"], .badge, span')
      .filter({
        hasText:
          /^(À préparer|Colisage en cours|Colisage terminé|Expédié|Livré|Annulé)$/,
      })
      .first();
    await expect(badge).toBeVisible();
    await expect(badge).toHaveScreenshot(
      `bl-current-${testInfo.project.name}.png`,
      { maxDiffPixelRatio: 0.02 },
    );
  });
});