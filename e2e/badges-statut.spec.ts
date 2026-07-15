import { test, expect } from "@playwright/test";
import {
  hasAuthSession,
  resetFixtures,
  setFactureStatut,
  FIXTURE_IDS,
} from "./fixtures/supabase";
import { restoreLovableSession } from "./fixtures/auth";

// Correspondance officielle définie dans src/lib/factures-api.ts
const EXPECTED = {
  annulee: { label: "Annulée", color: "rgb(100, 116, 139)" }, // #64748B
  avoir:   { label: "Avoir",   color: "rgb(139, 92, 246)"  }, // #8B5CF6
  payee:   { label: "Payée",   color: "rgb(16, 185, 129)"  }, // #10B981
  partielle:{ label: "Partielle", color: "rgb(249, 115, 22)" }, // #F97316
  impayee: { label: "Impayée", color: "rgb(239, 68, 68)"   }, // #EF4444
} as const;

test.describe("Badges statut facture (desktop + mobile via projet Playwright)", () => {
  test.skip(!hasAuthSession, "Lovable-injected Supabase session required");

  for (const statut of ["annulee", "avoir"] as const) {
    test(`badge « ${EXPECTED[statut].label} » (${statut}) sur la fiche facture`, async ({
      page,
      context,
      baseURL,
    }) => {
      await resetFixtures();
      await setFactureStatut(statut);

      const base = baseURL ?? "http://localhost:8080";
      await restoreLovableSession(context, page, base);

      await page.goto(`${base}/factures/${FIXTURE_IDS.facture}`, {
        waitUntil: "domcontentloaded",
      });

      const badge = page.getByText(EXPECTED[statut].label, { exact: true }).first();
      await expect(badge).toBeVisible({ timeout: 10_000 });

      const bg = await badge.evaluate((el) => getComputedStyle(el).backgroundColor);
      expect(bg).toBe(EXPECTED[statut].color);
    });
  }
});