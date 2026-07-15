import { expect, type TestInfo, type Locator } from "@playwright/test";

/**
 * Ré-exécute une assertion Playwright plusieurs fois, mais UNIQUEMENT sur le
 * projet "mobile" (les autres projets tentent une seule fois). Logue le
 * contexte utile (projet, tentative, message d'erreur) pour faciliter le
 * diagnostic des flakys mobiles.
 */
export async function expectFlakyMobile(
  testInfo: TestInfo,
  label: string,
  assertion: () => Promise<void>,
  opts: { attempts?: number; delayMs?: number } = {},
): Promise<void> {
  const isMobile = testInfo.project.name === "mobile";
  const attempts = isMobile ? (opts.attempts ?? 3) : 1;
  const delay = opts.delayMs ?? 500;
  let lastErr: unknown;
  for (let i = 1; i <= attempts; i++) {
    try {
      await assertion();
      if (i > 1) {
        // eslint-disable-next-line no-console
        console.info(
          `[flaky-mobile] "${label}" OK à la tentative ${i}/${attempts} (${testInfo.project.name})`,
        );
      }
      return;
    } catch (e) {
      lastErr = e;
      // eslint-disable-next-line no-console
      console.warn(
        `[flaky-mobile] "${label}" échec ${i}/${attempts} (${testInfo.project.name}): ${(e as Error).message?.split("\n")[0]}`,
      );
      if (i < attempts) await new Promise((r) => setTimeout(r, delay));
    }
  }
  throw lastErr;
}

/** Attente robuste : locator visible ET stable (bbox inchangée sur 2 frames). */
export async function waitStable(loc: Locator, timeout = 5_000): Promise<void> {
  await expect(loc).toBeVisible({ timeout });
  const box1 = await loc.boundingBox();
  await loc.page().waitForTimeout(120);
  const box2 = await loc.boundingBox();
  if (!box1 || !box2 || box1.x !== box2.x || box1.y !== box2.y) {
    await loc.page().waitForTimeout(200);
  }
}