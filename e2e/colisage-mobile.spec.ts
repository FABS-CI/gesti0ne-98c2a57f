import { test, expect } from "./fixtures/base";
import { hasAuthSession, FIXTURE_IDS } from "./fixtures/supabase";

test.describe("Colisage — mobile QR & mise en page", () => {
  test.skip(!hasAuthSession, "Lovable-injected Supabase session required");
  test.skip(
    ({ }, testInfo) => testInfo.project.name !== "mobile",
    "Assertions mobile-only",
  );

  test("la page colisage reste utilisable sur mobile (pas de débordement horizontal)", async ({
    page,
    baseURL,
  }) => {
    const base = baseURL ?? "http://localhost:8080";
    await page.goto(`${base}/colisage/${FIXTURE_IDS.bl}`, { waitUntil: "domcontentloaded" });
    // Attendre le rendu des étiquettes
    await page.waitForSelector("[data-colis-id]", { timeout: 15_000 });

    const overflow = await page.evaluate(() => ({
      scrollW: document.documentElement.scrollWidth,
      clientW: document.documentElement.clientWidth,
    }));
    // Tolérance 2px pour arrondis
    expect(overflow.scrollW).toBeLessThanOrEqual(overflow.clientW + 2);
  });

  test("chaque étiquette affiche un QR code visible et non tronqué", async ({ page, baseURL }) => {
    const base = baseURL ?? "http://localhost:8080";
    await page.goto(`${base}/colisage/${FIXTURE_IDS.bl}`, { waitUntil: "domcontentloaded" });
    await page.waitForSelector("[data-colis-id]", { timeout: 15_000 });

    const etiquettes = page.locator("[data-colis-id]");
    const count = await etiquettes.count();
    expect(count).toBeGreaterThan(0);

    for (let i = 0; i < count; i++) {
      const et = etiquettes.nth(i);
      // QR code = <svg> ou <canvas> ou <img> avec data-qr / aria-label QR
      const qr = et.locator("svg, canvas, img").first();
      await expect(qr).toBeVisible({ timeout: 5_000 });

      const box = await qr.boundingBox();
      expect(box, `étiquette ${i} : QR sans bounding box`).not.toBeNull();
      if (!box) continue;

      // QR lisible : côté minimum ≥ 60 px à l'écran mobile
      expect(box.width).toBeGreaterThanOrEqual(60);
      expect(box.height).toBeGreaterThanOrEqual(60);

      // Non tronqué : contenu du carton ne dépasse pas le viewport
      const vw = page.viewportSize()?.width ?? 375;
      const cartonBox = await et.boundingBox();
      if (cartonBox) {
        // L'étiquette peut scroller horizontalement dans son conteneur,
        // mais le QR lui-même doit rester dans les bornes du carton.
        expect(box.x).toBeGreaterThanOrEqual(cartonBox.x - 1);
        expect(box.x + box.width).toBeLessThanOrEqual(cartonBox.x + cartonBox.width + 1);
      }
      expect(box.x).toBeLessThan(vw); // au moins partiellement dans le viewport
    }
  });
});
