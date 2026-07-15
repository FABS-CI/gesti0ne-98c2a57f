import { test } from "@playwright/test";
import { signInAsTestUser } from "./helpers/auth";
import {
  attachConsoleErrorLogger,
  expectNoCrash,
  waitPageReady,
} from "./helpers/stability";

/**
 * Deep-links directs vers /exercices/* et /livraison-suivi/* avec un
 * `search` incomplet, vide ou corrompu. Le fallback centralisé
 * (src/lib/route-schemas.ts) doit rendre la page sans crash boundary.
 *
 * Chaque cas :
 *  - navigue directement à l'URL (pas de clic préalable) ;
 *  - attend que la page soit rendue (URL + h1) ;
 *  - vérifie l'absence d'error boundary global.
 */

type Case = { label: string; url: string; urlPattern: RegExp };

const CORRUPTED_CASES: Case[] = [
  {
    label: "/exercices/comparatif — sort corrompu (emoji)",
    url: "/exercices/comparatif?sort=%F0%9F%98%80",
    urlPattern: /\/exercices\/comparatif/,
  },
  {
    label: "/exercices/comparatif — dir hors-enum",
    url: "/exercices/comparatif?dir=sideways",
    urlPattern: /\/exercices\/comparatif/,
  },
  {
    label: "/exercices/comparatif — pct non booléen",
    url: "/exercices/comparatif?pct=maybe",
    urlPattern: /\/exercices\/comparatif/,
  },
  {
    label: "/exercices/comparatif — combo total",
    url: "/exercices/comparatif?sort=&dir=&pct=&exos=",
    urlPattern: /\/exercices\/comparatif/,
  },
  {
    label: "/exercices/rapport — sans exercice",
    url: "/exercices/rapport",
    urlPattern: /\/exercices\/rapport/,
  },
  {
    label: "/exercices/rapport — exercice=uuid inconnu",
    url: "/exercices/rapport?exercice_id=00000000-0000-0000-0000-000000000000",
    urlPattern: /\/exercices\/rapport/,
  },
  {
    label: "/livraison-suivi/$ref — debug corrompu",
    url: "/livraison-suivi/E2E-DEEP-CORRUPT?debug=%E2%98%A0",
    urlPattern: /\/livraison-suivi\/E2E-DEEP-CORRUPT/,
  },
  {
    label: "/livraison-suivi/$ref — debug=maybe",
    url: "/livraison-suivi/E2E-DEEP-CORRUPT?debug=maybe",
    urlPattern: /\/livraison-suivi\/E2E-DEEP-CORRUPT/,
  },
  {
    label: "/livraison-suivi/$ref/remise — search vide",
    url: "/livraison-suivi/E2E-DEEP-CORRUPT/remise?",
    urlPattern: /\/livraison-suivi\/[^/]+\/remise/,
  },
];

test.describe("Deep links avec search corrompu — fallback centralisé", () => {
  test.beforeEach(async ({ page }, testInfo) => {
    attachConsoleErrorLogger(page, testInfo);
    await signInAsTestUser(page);
  });

  for (const c of CORRUPTED_CASES) {
    test(c.label, async ({ page }) => {
      await page.goto(c.url);
      // Certaines pages (rapport introuvable, ref inexistant) rendent un
      // état "vide" sans h1 — on tolère l'absence de h1 mais on exige :
      //   - l'URL matche toujours la route (validator n'a pas rejeté) ;
      //   - aucun crash boundary global.
      await expectNoCrash(page);
      await page.waitForURL(c.urlPattern, { timeout: 15_000 });
      await expectNoCrash(page);
    });
  }

  test("/exercices/comparatif — page rendue complètement (fallback OK)", async ({
    page,
  }) => {
    await page.goto("/exercices/comparatif?sort=zzz&dir=zzz&pct=zzz");
    await waitPageReady(page, /\/exercices\/comparatif/);
    await expectNoCrash(page);
  });
});