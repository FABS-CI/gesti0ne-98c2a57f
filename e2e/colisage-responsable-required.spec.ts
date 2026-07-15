import { test, expect } from "./fixtures/base";
import { hasAuthSession, FIXTURE_IDS, resetFixtures, getAuthedClient } from "./fixtures/supabase";

test.describe("Colisage — Responsable obligatoire", () => {
  test.skip(!hasAuthSession, "Session Supabase Lovable requise");

  test.beforeEach(async () => {
    await resetFixtures();
  });

  test("soumission bloquée quand le responsable est vide (toast + focus + aucun colis créé)", async ({
    page,
    baseURL,
  }) => {
    const base = baseURL ?? "http://localhost:8080";
    const client = getAuthedClient();

    // Compter les colis avant tentative
    const { count: before } = await client
      .from("colis")
      .select("colis_id", { count: "exact", head: true })
      .eq("bl_id", FIXTURE_IDS.bl);

    await page.goto(`${base}/colisage/${FIXTURE_IDS.bl}`, { waitUntil: "domcontentloaded" });

    // Cliquer le bouton de soumission (même s'il est désactivé faute de composition,
    // on force via keyboard submit du form pour déclencher handleSubmit).
    const submit = page.getByRole("button", { name: /Valider|Regénérer/i }).first();
    await submit.waitFor({ state: "visible", timeout: 10_000 });

    // Soumettre le formulaire via Enter (indépendant du disabled du bouton).
    await page.evaluate(() => {
      const form = document.querySelector("form");
      form?.dispatchEvent(new Event("submit", { cancelable: true, bubbles: true }));
    });

    // Toast d'erreur avec le nom exact du champ
    await expect(
      page.getByText(/Responsable du colisage/i).first(),
    ).toBeVisible({ timeout: 5_000 });

    // Message d'erreur sous le champ
    await expect(page.getByText(/Responsable du colisage requis/i)).toBeVisible();

    // Focus mis sur le trigger « Responsable »
    const focused = await page.evaluate(
      () => document.activeElement?.getAttribute("aria-label"),
    );
    expect(focused).toBe("Responsable du colisage");

    // Aucun colis n'a été créé
    const { count: after } = await client
      .from("colis")
      .select("colis_id", { count: "exact", head: true })
      .eq("bl_id", FIXTURE_IDS.bl);
    expect(after ?? 0).toBe(before ?? 0);
  });
});