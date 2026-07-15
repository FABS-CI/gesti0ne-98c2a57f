import { test, expect } from "./fixtures/base";
import {
  hasAuthSession,
  FIXTURE_IDS,
  resetFixtures,
  getAuthedClient,
  getBlFixture,
} from "./fixtures/supabase";

/**
 * Après suppression d'un colisage :
 *  - le BL revient au statut « a_preparer »
 *  - il réapparaît dans la liste /colisage
 *  - un nouveau colisage peut être créé (aucun colis résiduel, page modifiable)
 */
test.describe("Colisage — Suppression réversible", () => {
  test.skip(!hasAuthSession, "Session Supabase Lovable requise");

  test.beforeEach(async () => {
    await resetFixtures();
  });

  test("supprimer un colisage remet la commande dans « À traiter » et permet une recréation", async ({
    page,
    baseURL,
  }) => {
    const base = baseURL ?? "http://localhost:8080";
    const client = getAuthedClient();

    // La fixture contient déjà des colis pour ce BL (colis1/colis2).
    // 1) Supprimer le colisage via l'RPC métier.
    const { error } = await client.rpc("supprimer_colisage", {
      p_bl_id: FIXTURE_IDS.bl,
      p_motif: "e2e — test de recréation",
    });
    expect(error).toBeNull();

    // 2) Le BL doit être repassé à « a_preparer ».
    const bl = await getBlFixture();
    expect(bl.statut).toBe("a_preparer");

    // 3) Plus aucun colis lié à ce BL.
    const { count: colisRestants } = await client
      .from("colis")
      .select("colis_id", { count: "exact", head: true })
      .eq("bl_id", FIXTURE_IDS.bl);
    expect(colisRestants ?? 0).toBe(0);

    // 4) Le BL réapparaît dans la liste /colisage (« À traiter »).
    await page.goto(`${base}/colisage`, { waitUntil: "domcontentloaded" });
    await expect(
      page.locator(`[data-bl-id="${FIXTURE_IDS.bl}"], a[href*="${FIXTURE_IDS.bl}"]`).first(),
    ).toBeVisible({ timeout: 10_000 });

    // 5) La page détail est modifiable : le formulaire de création est présent.
    await page.goto(`${base}/colisage/${FIXTURE_IDS.bl}`, { waitUntil: "domcontentloaded" });
    await expect(
      page.getByRole("heading", { name: /Créer le colisage|Refaire le colisage/i }),
    ).toBeVisible({ timeout: 10_000 });
    await expect(page.getByLabel(/Responsable du colisage/i)).toBeVisible();
  });
});