import { test, expect, type Page } from "@playwright/test";
import { signInAsTestUser } from "./helpers/auth";
import { createRemiseFixture, deleteRemiseFixture, type RemiseFixture } from "./helpers/fixtures";

async function gotoDetail(page: Page, ref: string) {
  await page.goto(`/livraison-suivi/${encodeURIComponent(ref)}`);
  await expect(page.getByText(/Suivi —/)).toBeVisible({ timeout: 15_000 });
}

test.describe("Suivi des livraisons — flux avancer / retry / pagination", () => {
  let fx: RemiseFixture;

  test.beforeAll(async () => {
    fx = await createRemiseFixture({ withColis: true, withLivreur: true });
  });
  test.afterAll(async () => {
    if (fx) await deleteRemiseFixture(fx);
  });
  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("avancer d'une étape ajoute une ligne dans l'historique", async ({ page }) => {
    await gotoDetail(page, fx.commandeRef);

    // Le premier bouton est « Remise au livreur » (route dédiée) — on le suit.
    await page.getByRole("link", { name: /Remise au livreur/i }).click();
    await expect(page).toHaveURL(/\/remise$/);

    // Valide la remise puis revient au détail
    const valider = page.getByRole("button", { name: /Valider l'étape|Valider/i }).first();
    await expect(valider).toBeEnabled({ timeout: 10_000 });
    await valider.click();

    await gotoDetail(page, fx.commandeRef);
    await expect(page.getByText(/Historique chronologique/)).toBeVisible();
    await expect(page.getByText(/Remise au livreur/i).first()).toBeVisible({ timeout: 10_000 });
  });

  test("erreur Supabase sur détail affiche un bandeau avec bouton Réessayer", async ({ page }) => {
    // On coupe toutes les requêtes livsuivi_commandes avant le chargement
    let hit = 0;
    await page.route(/\/rest\/v1\/livsuivi_commandes/, async (route) => {
      hit += 1;
      if (hit === 1) return route.fulfill({ status: 500, body: "server error" });
      return route.continue();
    });
    await page.goto(`/livraison-suivi/${encodeURIComponent(fx.commandeRef)}`);
    await expect(page.getByText(/Échec du chargement du suivi/i)).toBeVisible({ timeout: 15_000 });
    await page.getByRole("button", { name: /Réessayer/i }).click();
    await expect(page.getByText(/Suivi —/)).toBeVisible({ timeout: 15_000 });
  });

  test("historique — sentinel de pagination visible", async ({ page }) => {
    await gotoDetail(page, fx.commandeRef);
    const sentinel = page.getByTestId("histo-sentinel");
    await expect(sentinel).toBeVisible();
    // Le texte affiche « n étape(s) · tout chargé » quand il n'y a plus de page
    // ou « n / total » sinon — les deux formats sont acceptés.
    await expect(sentinel).toHaveText(/(tout chargé|\d+\s*\/\s*\d+|Chargement…)/);
  });
});