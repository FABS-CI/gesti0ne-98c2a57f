import { test, expect, type Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { signInAsTestUser } from "./helpers/auth";

/**
 * Recalage systématique après suppression d'un colisage :
 *  - 2 commandes / 2 BL sont créées avec un colisage complet
 *  - on supprime le colisage d'UN seul des deux
 *  - les deux BL doivent ensuite apparaître au statut « a_preparer »
 *    et être visibles/colisables dans /colisage (« À traiter »)
 */

const SUPABASE_URL = process.env.VITE_SUPABASE_URL!;
const SUPABASE_KEY = process.env.VITE_SUPABASE_PUBLISHABLE_KEY!;

function db(): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
async function login(c: SupabaseClient) {
  const { error } = await c.auth.signInWithPassword({
    email: process.env.E2E_TEST_EMAIL!,
    password: process.env.E2E_TEST_PASSWORD!,
  });
  if (error) throw error;
}
const suf = () => Math.random().toString(36).slice(2, 8).toUpperCase();

async function seedCmdAvecColisage() {
  const c = db();
  await login(c);
  const s = suf();
  const { data: cli } = await c
    .from("clients").insert({ nom: `E2E_RC_${s}` })
    .select("client_id").single();
  const { data: cmd } = await c
    .from("commandes")
    .insert({
      client_id: cli!.client_id,
      numero: `E2E-RC-${s}`,
      date_commande: new Date().toISOString().slice(0, 10),
    })
    .select("commande_id").single();
  const { data: bl } = await c
    .from("bons_livraison")
    .insert({
      commande_id: cmd!.commande_id,
      statut: "a_preparer",
      numero: `BL-${s}`,
    })
    .select("bl_id").single();
  const { data: col } = await c
    .from("colis")
    .insert({
      commande_id: cmd!.commande_id,
      bl_id: bl!.bl_id,
      reference: `COL-${s}`,
      nb_cartons: 1,
      destinataire: `E2E_RC_${s}`,
      date_colisage: new Date().toISOString().slice(0, 10),
    })
    .select("colis_id").single();
  return {
    clientId: cli!.client_id,
    commandeId: cmd!.commande_id,
    blId: bl!.bl_id,
    colisId: col!.colis_id,
  };
}

async function cleanup(ids: {
  clientId: string; commandeId: string; blId: string; colisId?: string;
}) {
  const c = db();
  await login(c);
  await c.from("colis").delete().eq("bl_id", ids.blId);
  await c.from("bons_livraison").delete().eq("bl_id", ids.blId);
  await c.from("commandes").delete().eq("commande_id", ids.commandeId);
  await c.from("clients").delete().eq("client_id", ids.clientId);
}

async function blRowVisible(page: Page, blId: string) {
  return page
    .locator(`[data-bl-id="${blId}"], a[href*="${blId}"]`)
    .first();
}

test.describe("Colisage — recalage après suppression sur 2 commandes", () => {
  test("les 2 BL restent « À préparer » et colisables", async ({ page }) => {
    await signInAsTestUser(page);
    const a = await seedCmdAvecColisage();
    const b = await seedCmdAvecColisage();
    try {
      const c = db();
      await login(c);

      // Supprimer le colisage de la 1re commande uniquement.
      const { error } = await c.rpc("supprimer_colisage", {
        p_bl_id: a.blId,
        p_motif: "e2e — recalage 2 commandes",
      });
      expect(error).toBeNull();

      // Les 2 BL doivent être au statut a_preparer.
      const { data: bls } = await c
        .from("bons_livraison")
        .select("bl_id,statut")
        .in("bl_id", [a.blId, b.blId]);
      const byId = Object.fromEntries((bls ?? []).map((r) => [r.bl_id, r.statut]));
      expect(byId[a.blId]).toBe("a_preparer");
      expect(byId[b.blId]).toBe("a_preparer");

      // Le colis de A a été supprimé, celui de B est intact.
      const { count: nColisA } = await c
        .from("colis").select("colis_id", { count: "exact", head: true }).eq("bl_id", a.blId);
      const { count: nColisB } = await c
        .from("colis").select("colis_id", { count: "exact", head: true }).eq("bl_id", b.blId);
      expect(nColisA ?? 0).toBe(0);
      expect(nColisB ?? 0).toBe(1);

      // Les 2 BL apparaissent dans la liste /colisage (« À traiter »).
      await page.goto("/colisage");
      await page.waitForLoadState("networkidle");
      await expect(await blRowVisible(page, a.blId)).toBeVisible({ timeout: 15_000 });
      await expect(await blRowVisible(page, b.blId)).toBeVisible({ timeout: 15_000 });

      // Les 2 pages détails sont ouvrables et proposent le formulaire de colisage.
      for (const blId of [a.blId, b.blId]) {
        await page.goto(`/colisage/${blId}`);
        await expect(
          page.getByRole("heading", { name: /Créer le colisage|Refaire le colisage/i }),
        ).toBeVisible({ timeout: 15_000 });
      }
    } finally {
      await cleanup(a);
      await cleanup(b);
    }
  });
});