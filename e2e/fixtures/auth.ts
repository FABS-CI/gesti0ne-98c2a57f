import type { BrowserContext, Page } from "@playwright/test";

/**
 * Restore the Lovable-injected Supabase session into the current browser
 * context before navigating to any authenticated route.
 * No-op if the session env vars are not present (LOVABLE_BROWSER_AUTH_STATUS != "injected").
 */
export async function restoreLovableSession(
  context: BrowserContext,
  page: Page,
  baseURL: string,
): Promise<boolean> {
  const status = process.env.LOVABLE_BROWSER_AUTH_STATUS;
  if (status !== "injected") return false;

  const storageKey = process.env.LOVABLE_BROWSER_SUPABASE_STORAGE_KEY;
  const sessionJson = process.env.LOVABLE_BROWSER_SUPABASE_SESSION_JSON;
  const cookiesJson = process.env.LOVABLE_BROWSER_SUPABASE_COOKIES_JSON;

  if (cookiesJson) {
    const cookies = JSON.parse(cookiesJson).map((c: Record<string, unknown>) => ({
      ...c,
      url: baseURL,
    }));
    await context.addCookies(cookies);
  }

  await page.goto(baseURL, { waitUntil: "domcontentloaded" });
  if (storageKey && sessionJson) {
    await page.evaluate(
      ([k, v]) => window.localStorage.setItem(k, v),
      [storageKey, sessionJson],
    );
  }
  return true;
}