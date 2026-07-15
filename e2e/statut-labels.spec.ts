import { test, expect } from "./fixtures/base";
import { hasAuthSession, setFactureStatut, FIXTURE_IDS } from "./fixtures/supabase";

// Mapping officiel BD -> UI (src/lib/factures-api.ts)
const DB_TO_LABEL: Record<string, string> = {
  impayee: "Impayée",
  partielle: "Partielle",
  payee: "Payée",
  annulee: "Annulée",
  avoir: "Avoir",
};

test.describe("Cohérence libellés UI ↔ valeurs BD", () => {
  test.skip(!hasAuthSession, "Lovable-injected Supabase session required");

  for (const [dbValue, label] of Object.entries(DB_TO_LABEL)) {
    test(`statut "${dbValue}" affiche le libellé "${label}"`, async ({ page, baseURL }) => {
      await setFactureStatut(dbValue);
      const base = baseURL ?? "http://localhost:8080";
      await page.goto(`${base}/factures/${FIXTURE_IDS.facture}`, {
        waitUntil: "domcontentloaded",
      });
      await expect(
        page.getByText(label, { exact: true }).first(),
      ).toBeVisible({ timeout: 10_000 });
    });
  }
});