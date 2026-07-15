import { test, expect, type Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { signInAsTestUser } from "./helpers/auth";

/**
 * Change de « lignes par page » (pageSize) puis revient au paramétrage
 * précédent : la ligne du suivi ne doit jamais être dupliquée.
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

async function seedLivSuivi() {
  const c = db();
  await login(c);
  const s = suf();
  const { data: cli } = await c
    .from("clients").insert({ nom: `E2E_PS_${s}` })
    .select("client_id").single();
  const commandeRef = `E2E-PS-${s}`;
  const { data: cmd } = await c
    .from("commandes")
    .insert({
      client_id: cli!.client_id,
      numero: commandeRef,
      date_commande: new Date().toISOString().slice(0, 10),
    })
    .select("commande_id").single();
  const { data: liv } = await c
    .from("livsuivi_commandes")
    .insert({
      commande_id: cmd!.commande_id,
      type_livraison: "direct",
      statut: "preparee",
    })
    .select("id").single();
  return {
    clientId: cli!.client_id,
    commandeId: cmd!.commande_id,
    commandeRef,
    livSuiviId: liv!.id,
  };
}

async function cleanup(ids: { clientId: string; commandeId: string }) {
  const c = db();
  await login(c);
  await c.from("livsuivi_commandes").delete().eq("commande_id", ids.commandeId);
  await c.from("commandes").delete().eq("commande_id", ids.commandeId);
  await c.from("clients").delete().eq("client_id", ids.clientId);
}

async function countRows(page: Page, ref: string) {
  return await page.locator("tr", { hasText: ref }).count();
}

async function setPageSize(page: Page, size: "10" | "25" | "50") {
  await page.getByTestId("livsuivi-page-size").click();
  await page.getByRole("option", { name: size, exact: true }).click();
}

test.describe("Livraison suivi — changement de pageSize", () => {
  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("ne duplique pas la ligne quand on change puis restaure pageSize", async ({ page }) => {
    const seed = await seedLivSuivi();
    try {
      await page.goto("/livraison-suivi");
      await expect(
        page.getByRole("row", { name: new RegExp(seed.commandeRef) }),
      ).toBeVisible({ timeout: 15_000 });
      expect(await countRows(page, seed.commandeRef)).toBe(1);

      // 25 (défaut) → 10
      await setPageSize(page, "10");
      await page.waitForTimeout(200);
      expect(await countRows(page, seed.commandeRef)).toBe(1);

      // 10 → 50
      await setPageSize(page, "50");
      await page.waitForTimeout(200);
      expect(await countRows(page, seed.commandeRef)).toBe(1);

      // 50 → 25 (retour au paramétrage précédent)
      await setPageSize(page, "25");
      await page.waitForTimeout(200);
      expect(await countRows(page, seed.commandeRef)).toBe(1);
    } finally {
      await cleanup(seed);
    }
  });
});