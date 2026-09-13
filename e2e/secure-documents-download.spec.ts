import { test, expect } from "@playwright/test";

// Tests API purs (pas de page/session nécessaire) pour la route de
// téléchargement sécurisée /api/secure-documents/$token/download.
// Couvre la partie de la matrice du Prompt 8 qui ne dépend d'aucune donnée
// métier réelle. Le cas "téléchargement réussi" est séparé plus bas et
// nécessite un jeton de document réellement certifié AUTHENTIC (fourni via
// la variable d'environnement E2E_TEST_VERIFIED_TOKEN) : il est ignoré tant
// que cette variable n'est pas fournie.

const BASE = process.env.PLAYWRIGHT_BASE_URL ?? "http://localhost:8080";
const downloadUrl = (token: string) => `${BASE}/api/secure-documents/${encodeURIComponent(token)}/download`;

test.describe("Téléchargement sécurisé — cas d'échec et falsification", () => {
  test("jeton de mauvais format -> 400, aucun PDF", async ({ request }) => {
    const res = await request.get(downloadUrl("court"));
    expect(res.status()).toBe(400);
    expect(res.headers()["content-type"]).not.toContain("application/pdf");
  });

  test("jeton inconnu (mais bien formé) -> refusé, aucun PDF", async ({ request }) => {
    const fakeToken = "A".repeat(43); // même longueur qu'un vrai jeton base64url 256 bits
    const res = await request.get(downloadUrl(fakeToken));
    expect(res.status()).toBeGreaterThanOrEqual(400);
    expect(res.headers()["content-type"]).not.toContain("application/pdf");
  });

  test("jeton avec caractères non autorisés (tentative d'injection) -> 400", async ({ request }) => {
    const res = await request.get(downloadUrl("../../etc/passwd"));
    expect(res.status()).toBe(400);
  });

  test("réponse d'échec ne révèle aucune donnée confidentielle", async ({ request }) => {
    const fakeToken = "B".repeat(43);
    const res = await request.get(downloadUrl(fakeToken));
    const body = await res.json().catch(() => ({}));
    const raw = JSON.stringify(body).toLowerCase();
    // Pas de trace de nom de client, montant, id interne, message technique de la base.
    expect(raw).not.toMatch(/postgres|supabase|stack|sql|client_id|document_id/);
  });

  test("en-têtes anti-cache présents même en échec", async ({ request }) => {
    const fakeToken = "C".repeat(43);
    const res = await request.get(downloadUrl(fakeToken));
    expect(res.headers()["cache-control"]).toContain("no-store");
    expect(res.headers()["x-content-type-options"]).toBe("nosniff");
  });

  test("changement de méthode HTTP (POST) -> rejeté", async ({ request }) => {
    const res = await request.post(downloadUrl("D".repeat(43)));
    expect(res.status()).toBeGreaterThanOrEqual(400);
    expect(res.status()).not.toBe(200);
  });

  test("téléchargements rapides répétés -> rate limiting déclenché", async ({ request }) => {
    const token = "E".repeat(43);
    const results = await Promise.all(
      Array.from({ length: 15 }, () => request.get(downloadUrl(token))),
    );
    const statuses = results.map((r) => r.status());
    expect(statuses.some((s) => s === 429)).toBe(true);
  });

  test("aucune différence de timing exploitable entre jeton inexistant et jeton mal formé", async ({
    request,
  }) => {
    const timeIt = async (token: string) => {
      const start = Date.now();
      await request.get(downloadUrl(token));
      return Date.now() - start;
    };
    const tMalforme = await timeIt("x");
    const tInexistant = await timeIt("F".repeat(43));
    // Tolérance large : on vérifie l'absence d'écart flagrant (>2s), pas une
    // égalité stricte qui serait fragile en CI partagée.
    expect(Math.abs(tMalforme - tInexistant)).toBeLessThan(2000);
  });
});

test.describe("Téléchargement sécurisé — cas nominal (nécessite un jeton réel)", () => {
  const realToken = process.env.E2E_TEST_VERIFIED_TOKEN;
  test.skip(!realToken, "E2E_TEST_VERIFIED_TOKEN requis : jeton d'un document AUTHENTIC réel");

  test("jeton valide -> PDF renvoyé avec les bons en-têtes", async ({ request }) => {
    const res = await request.get(downloadUrl(realToken!));
    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toBe("application/pdf");
    expect(res.headers()["content-disposition"]).toContain("attachment");
    expect(res.headers()["cache-control"]).toContain("no-store");
    const body = await res.body();
    expect(body.subarray(0, 4).toString("latin1")).toBe("%PDF");
  });

  test("même jeton réutilisé une deuxième fois -> revalidation complète, toujours cohérent", async ({
    request,
  }) => {
    const res1 = await request.get(downloadUrl(realToken!));
    const res2 = await request.get(downloadUrl(realToken!));
    expect(res1.status()).toBe(res2.status());
  });
});
