import { test, expect } from "@playwright/test";
import { signInAsTestUser } from "./helpers/auth";

/**
 * Smoke-tests des schémas `search` centralisés (src/lib/route-schemas.ts).
 *
 * Objectifs :
 *  1. La navigation vers ces routes fonctionne (pas de 404 / crash boundary).
 *  2. Les valeurs `search` invalides ou absentes sont remplacées par les
 *     défauts via `fallback()` — l'app ne crashe pas et le contenu de la
 *     page se rend correctement.
 *
 * Ces tests ne dépendent pas des fixtures métier : ils vérifient uniquement
 * la couche routing + validation search.
 */

test.describe("Schéma search centralisé", () => {
  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("exercices/comparatif accepte l'URL nue et applique les défauts", async ({ page }) => {
    await page.goto("/exercices/comparatif");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    // Aucune redirection d'erreur.
    await expect(page).toHaveURL(/\/exercices\/comparatif/);
  });

  test("exercices/comparatif ignore les params invalides sans crasher", async ({ page }) => {
    await page.goto("/exercices/comparatif?sort=%E2%98%A0&dir=zzz&pct=notabool");
    // La page se rend malgré des params corrompus (fallback → code/asc/true).
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  });

  test("livraison-suivi/$commandeRef : URL sans `debug` reste valide", async ({ page }) => {
    // La ref n'existe probablement pas — on tolère un état « Introuvable »
    // mais on refuse un crash boundary (bordure d'erreur globale).
    await page.goto("/livraison-suivi/E2E-SCHEMA-SMOKE");
    const crashed = await page
      .getByText(/quelque chose s'est mal passé|something went wrong/i)
      .isVisible()
      .catch(() => false);
    expect(crashed).toBe(false);
  });

  test("livraison-suivi/$commandeRef : `?debug=1` est accepté par le validator", async ({ page }) => {
    await page.goto("/livraison-suivi/E2E-SCHEMA-SMOKE?debug=1");
    await expect(page).toHaveURL(/\/livraison-suivi\/E2E-SCHEMA-SMOKE/);
  });
});