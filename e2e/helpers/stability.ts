import { expect, type Page, type TestInfo } from "@playwright/test";

/**
 * Helpers de stabilisation pour les tests de navigation e2e.
 *
 * Objectif : limiter les flakys CI en centralisant :
 *  - l'attente qu'une page soit « prête » (URL + heading visible + réseau idle),
 *  - la détection d'un crash boundary global (fallback centralisé OK ?),
 *  - la collecte automatique des erreurs console + pageerror,
 *  - un mini-wrapper de retry pour les assertions intrinsèquement instables.
 */

/** Attend que l'URL matche + que le h1 soit visible + réseau idle court. */
export async function waitPageReady(
  page: Page,
  urlPattern: RegExp | string,
  opts: { headingTimeout?: number } = {},
): Promise<void> {
  await expect(page).toHaveURL(urlPattern, { timeout: 15_000 });
  await page
    .waitForLoadState("networkidle", { timeout: 10_000 })
    .catch(() => {
      /* certains dashboards gardent un socket ouvert — non bloquant */
    });
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible({
    timeout: opts.headingTimeout ?? 15_000,
  });
}

/** Vérifie qu'aucun error boundary global n'est affiché. */
export async function expectNoCrash(page: Page): Promise<void> {
  const crashed = await page
    .getByText(/quelque chose s'est mal passé|something went wrong/i)
    .isVisible()
    .catch(() => false);
  expect(crashed, "Un error boundary global est affiché").toBe(false);
}

/**
 * Attache un collecteur qui logue automatiquement les erreurs console
 * et les exceptions non capturées. Les logs remontent dans le rapport
 * Playwright CI et facilitent le diagnostic des flakys.
 */
export function attachConsoleErrorLogger(page: Page, testInfo: TestInfo): void {
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      // eslint-disable-next-line no-console
      console.warn(`[console.error][${testInfo.title}] ${msg.text()}`);
    }
  });
  page.on("pageerror", (err) => {
    // eslint-disable-next-line no-console
    console.warn(`[pageerror][${testInfo.title}] ${err.message}`);
  });
}

/** Ré-essaie une assertion `fn` jusqu'à `attempts` fois. */
export async function retry<T>(
  fn: () => Promise<T>,
  opts: { attempts?: number; delayMs?: number; label?: string } = {},
): Promise<T> {
  const attempts = opts.attempts ?? 3;
  const delay = opts.delayMs ?? 400;
  let lastErr: unknown;
  for (let i = 1; i <= attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      lastErr = e;
      if (i < attempts) await new Promise((r) => setTimeout(r, delay));
    }
  }
  throw lastErr;
}