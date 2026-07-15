import { test, expect } from "./fixtures/base";
import { hasAuthSession, setFactureStatut, FIXTURE_IDS } from "./fixtures/supabase";
import { expectFlakyMobile } from "./fixtures/retry";

// Seuils WCAG AA simplifiés : ratio ≥ 4.5 pour texte normal, ≥ 3 pour texte >= 18px.
function relLum(rgb: [number, number, number]) {
  const toLin = (v: number) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  const [r, g, b] = rgb.map(toLin) as [number, number, number];
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
function contrast(a: [number, number, number], b: [number, number, number]) {
  const [l1, l2] = [relLum(a), relLum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
}
function parseRgb(s: string): [number, number, number] {
  const m = s.match(/rgba?\(([^)]+)\)/);
  if (!m) return [0, 0, 0];
  const [r, g, b] = m[1].split(",").map((v) => parseInt(v.trim(), 10));
  return [r, g, b];
}

test.describe("Badges statut — lisibilité mobile", () => {
  test.skip(!hasAuthSession, "Lovable-injected Supabase session required");
  test.skip(
    ({ }, testInfo) => testInfo.project.name !== "mobile",
    "Assertions mobile-only",
  );

  for (const statut of ["annulee", "avoir", "payee", "partielle", "impayee"] as const) {
    test(`badge "${statut}" reste visible et lisible sur mobile`, async ({ page, baseURL }, testInfo) => {
      await setFactureStatut(statut);
      const base = baseURL ?? "http://localhost:8080";
      await page.goto(`${base}/factures/${FIXTURE_IDS.facture}`, {
        waitUntil: "domcontentloaded",
      });

      const badge = page
        .locator('[class*="badge"], .badge, span')
        .filter({ hasText: /^(Annulée|Avoir|Payée|Partielle|Impayée)$/ })
        .first();
      await expectFlakyMobile(testInfo, `badge ${statut} visible`, async () => {
        await expect(badge).toBeVisible({ timeout: 10_000 });
      });

      const info = await badge.evaluate((el) => {
        const s = getComputedStyle(el);
        const r = el.getBoundingClientRect();
        return {
          bg: s.backgroundColor,
          color: s.color,
          fontSize: parseFloat(s.fontSize),
          width: r.width,
          height: r.height,
          top: r.top,
          left: r.left,
          right: r.right,
          vw: window.innerWidth,
        };
      });

      // Taille lisible et intégralement dans le viewport
      expect(info.fontSize).toBeGreaterThanOrEqual(10);
      expect(info.height).toBeGreaterThanOrEqual(16);
      expect(info.left).toBeGreaterThanOrEqual(0);
      expect(info.right).toBeLessThanOrEqual(info.vw);

      // Contraste texte / fond ≥ 3 (badge = texte large-ish, bold)
      const ratio = contrast(parseRgb(info.color), parseRgb(info.bg));
      expect(ratio).toBeGreaterThanOrEqual(3);
    });
  }
});