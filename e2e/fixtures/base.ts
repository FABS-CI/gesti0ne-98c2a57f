import { test as base, expect } from "@playwright/test";
import { hasAuthSession, resetFixtures } from "./supabase";
import { restoreLovableSession } from "./auth";

/**
 * Test étendu :
 *  - Re-seed automatique des fixtures avant chaque test (idempotent via e2e_reset).
 *  - Restauration automatique de la session Lovable si disponible.
 * Les tests qui n'ont pas besoin d'auth peuvent ignorer la restauration.
 */
export const test = base.extend<{ authedPage: void }>({
  authedPage: [
    async ({ page, context, baseURL }, use) => {
      if (hasAuthSession) {
        await resetFixtures();
        await restoreLovableSession(context, page, baseURL ?? "http://localhost:8080");
      }
      await use();
    },
    { auto: true },
  ],
});

export { expect };