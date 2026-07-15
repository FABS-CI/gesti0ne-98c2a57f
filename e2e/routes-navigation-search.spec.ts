import { test, expect } from "@playwright/test";
import { signInAsTestUser } from "./helpers/auth";
import {
  ensureAtLeastOneExercice,
  ensureAtLeastOneLivraisonSuivi,
} from "./helpers/fixtures-nav";

/**
 * Vérifie que les navigations déclenchées depuis les pages de listes
 * (et les boutons d'action) reconstruisent bien un `search` valide
 * accepté par le `validateSearch` de la route cible.
 *
 * Contrat implicite :
 *  - Aucun crash boundary ne s'affiche après le clic.
 *  - L'URL correspond au pattern attendu.
 *  - Le heading (h1) de la page cible est visible → la route a matché
 *    ET le validator n'a pas rejeté les params.
 */

async function expectNoCrash(page: import("@playwright/test").Page) {
  const crashed = await page
    .getByText(/quelque chose s'est mal passé|something went wrong/i)
    .isVisible()
    .catch(() => false);
  expect(crashed).toBe(false);
}

test.describe("Reconstruction du search en runtime — depuis les listes", () => {
  test.beforeAll(async () => {
    // Garantit que les listes ont des lignes cliquables (élimine les
    // test.skip() historiques quand l'environnement était vide).
    await ensureAtLeastOneExercice();
    await ensureAtLeastOneLivraisonSuivi();
  });

  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("Exercices → bouton « Comparatif » : URL comparatif valide + page rendue", async ({ page }) => {
    await page.goto("/exercices");
    await expect(page.getByRole("heading", { name: /exercices comptables/i })).toBeVisible();

    await page.getByRole("link", { name: /^comparatif$/i }).click();

    await expect(page).toHaveURL(/\/exercices\/comparatif(?:\?|$)/);
    // La page comparatif s'est bien affichée → validateSearch a accepté les defaults.
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expectNoCrash(page);
  });

  test("Exercices → bouton « Rapport d'exercice » : route atteinte sans rejet search", async ({ page }) => {
    await page.goto("/exercices");
    await page.getByRole("link", { name: /rapport d'exercice/i }).click();
    await expect(page).toHaveURL(/\/exercices\/rapport/);
    await expectNoCrash(page);
  });

  test("Rapport d'exercice → lien « Retour au comparatif » réutilise les défauts partagés", async ({ page }) => {
    // Force le fallback « exercice introuvable » : le bouton retour s'affiche.
    await page.goto("/exercices/rapport?exercice_id=00000000-0000-0000-0000-000000000000");
    const retour = page.getByRole("link", { name: /retour au comparatif/i });
    if (await retour.isVisible().catch(() => false)) {
      await retour.click();
      await expect(page).toHaveURL(/\/exercices\/comparatif(?:\?|$)/);
      await expectNoCrash(page);
    }
  });

  test("Liste livraison-suivi → clic ligne : URL /$commandeRef valide", async ({ page }) => {
    await page.goto("/livraison-suivi");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();

    const firstRef = page.locator('a[href^="/livraison-suivi/"]').first();
    await expect(firstRef).toBeVisible();

    const href = await firstRef.getAttribute("href");
    await firstRef.click();
    await expect(page).toHaveURL(new RegExp(href!.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    await expectNoCrash(page);
  });

  test("Détail livraison-suivi → bouton « Remise » : /$commandeRef/remise + no-crash", async ({ page }) => {
    await page.goto("/livraison-suivi");
    const firstRef = page.locator('a[href^="/livraison-suivi/"]').first();
    await expect(firstRef).toBeVisible();
    await firstRef.click();

    const btnRemise = page.getByRole("link", { name: /remise (au livreur|au transporteur)/i });
    const hasRemise = await btnRemise.isVisible().catch(() => false);
    test.skip(!hasRemise, "L'étape courante ne propose pas de remise sur cette commande.");
    await btnRemise.click();

    await expect(page).toHaveURL(/\/livraison-suivi\/[^/]+\/remise/);
    await expectNoCrash(page);
  });
});