import { expect, type Page } from "@playwright/test";

/**
 * Signe l'utilisateur de test via le formulaire /auth et attend la
 * redirection vers la partie authentifiée de l'app.
 * L'utilisateur DOIT avoir le rôle `super_admin` en base pour que
 * l'insertion des fixtures via l'API PostgREST passe la RLS.
 */
export async function signInAsTestUser(page: Page): Promise<void> {
  const email = process.env.E2E_TEST_EMAIL;
  const password = process.env.E2E_TEST_PASSWORD;
  if (!email || !password) {
    throw new Error(
      "E2E_TEST_EMAIL / E2E_TEST_PASSWORD sont requis pour lancer les tests E2E.",
    );
  }
  await page.goto("/auth");
  await page.getByLabel(/email/i).fill(email);
  await page.getByLabel(/mot de passe|password/i).first().fill(password);
  await page.getByRole("button", { name: /connexion|se connecter|sign in/i }).click();
  await expect(page).not.toHaveURL(/\/auth(\?|$)/, { timeout: 15_000 });
}

/**
 * Ouvre la page « Remise » et attend la fin du chargement Query.
 */
export async function gotoRemise(page: Page, commandeRef: string): Promise<void> {
  await page.goto(`/livraison-suivi/${encodeURIComponent(commandeRef)}/remise`);
  await expect(
    page.getByText(/Remise au (livreur|transporteur)|Aucun suivi/i),
  ).toBeVisible({ timeout: 15_000 });
}