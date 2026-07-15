import { defineConfig, devices } from "@playwright/test";

/**
 * Config Playwright pour les tests E2E.
 *
 * Prérequis :
 *   - Un utilisateur de test avec le rôle `super_admin` doit exister dans
 *     l'environnement ciblé. Fournissez ses identifiants via les variables :
 *       E2E_TEST_EMAIL     — email de l'utilisateur de test
 *       E2E_TEST_PASSWORD  — mot de passe associé
 *   - Le serveur de dev est lancé automatiquement par Playwright (bun dev).
 *
 * Exécution :  bun run test:e2e
 */
export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: process.env.CI
    ? [
        ["list"],
        ["html", { open: "never", outputFolder: "playwright-report" }],
        ["json", { outputFile: "playwright-report/results.json" }],
        ["github"],
      ]
    : [["list"]],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:8080",
    // Mode CI plus strict : trace complète + screenshot + vidéo sur échec
    // pour diagnostiquer rapidement les régressions de navigation.
    trace: process.env.CI ? "on-first-retry" : "retain-on-failure",
    screenshot: { mode: "only-on-failure", fullPage: true },
    video: process.env.CI ? "retain-on-failure" : "off",
    actionTimeout: 15_000,
    navigationTimeout: 20_000,
    viewport: { width: 1280, height: 900 },
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: process.env.E2E_BASE_URL
    ? undefined
    : {
        command: "bun run dev",
        url: "http://localhost:8080",
        reuseExistingServer: true,
        timeout: 120_000,
      },
});