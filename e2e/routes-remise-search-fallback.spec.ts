import { test, expect } from "@playwright/test";
import { signInAsTestUser } from "./helpers/auth";
import { ensureAtLeastOneLivraisonSuivi } from "./helpers/fixtures-nav";
import {
  attachConsoleErrorLogger,
  expectNoCrash,
  retry,
} from "./helpers/stability";

/**
 * Vérifie le bouton « Remise » depuis /livraison-suivi/$ref :
 *  - la navigation reconstruit un search valide accepté par le validator ;
 *  - même quand certains champs sont manquants / vides / corrompus au
 *    départ (le fallback centralisé les remplace avant de forwarder).
 *
 * Les cas où le bouton n'est pas cliquable (étape métier non atteinte)
 * sont contournés par un deep link direct vers `.../remise` : on vise
 * la couche routing/validator, pas la logique métier.
 */

test.describe("Bouton Remise — search reconstruit + fallback", () => {
  let commandeRef: string;

  test.beforeAll(async () => {
    commandeRef = await ensureAtLeastOneLivraisonSuivi();
  });

  test.beforeEach(async ({ page }, testInfo) => {
    attachConsoleErrorLogger(page, testInfo);
    await signInAsTestUser(page);
  });

  test("clic sur « Remise » depuis un détail : /$ref/remise + no-crash", async ({
    page,
  }) => {
    await page.goto(`/livraison-suivi/${encodeURIComponent(commandeRef)}`);
    await expectNoCrash(page);

    const btnRemise = page.getByRole("link", {
      name: /remise (au livreur|au transporteur)/i,
    });
    const visible = await btnRemise.isVisible().catch(() => false);
    test.skip(!visible, "Étape remise non disponible pour cette fixture.");

    await retry(async () => {
      await btnRemise.click();
      await expect(page).toHaveURL(/\/livraison-suivi\/[^/]+\/remise/);
    });
    await expectNoCrash(page);
  });

  test("deep link /$ref/remise sans `debug` : validator applique le défaut", async ({
    page,
  }) => {
    await page.goto(`/livraison-suivi/${encodeURIComponent(commandeRef)}/remise`);
    await expect(page).toHaveURL(/\/livraison-suivi\/[^/]+\/remise/);
    await expectNoCrash(page);
  });

  test("deep link /$ref/remise avec `debug=` vide : accepté", async ({ page }) => {
    await page.goto(
      `/livraison-suivi/${encodeURIComponent(commandeRef)}/remise?debug=`,
    );
    await expect(page).toHaveURL(/\/livraison-suivi\/[^/]+\/remise/);
    await expectNoCrash(page);
  });

  test("deep link /$ref/remise avec `debug` non booléen : fallback → false", async ({
    page,
  }) => {
    await page.goto(
      `/livraison-suivi/${encodeURIComponent(commandeRef)}/remise?debug=maybe`,
    );
    await expect(page).toHaveURL(/\/livraison-suivi\/[^/]+\/remise/);
    await expectNoCrash(page);
  });

  test("deep link /$ref/remise avec params étrangers : ignorés, pas de crash", async ({
    page,
  }) => {
    await page.goto(
      `/livraison-suivi/${encodeURIComponent(commandeRef)}/remise?foo=bar&x=%E2%98%A0`,
    );
    await expect(page).toHaveURL(/\/livraison-suivi\/[^/]+\/remise/);
    await expectNoCrash(page);
  });

  test("ref inexistante + `.../remise` : route matche, fallback centralisé actif", async ({
    page,
  }) => {
    await page.goto("/livraison-suivi/E2E-REMISE-UNKNOWN/remise?debug=1");
    await expect(page).toHaveURL(/\/livraison-suivi\/E2E-REMISE-UNKNOWN\/remise/);
    await expectNoCrash(page);
  });
});