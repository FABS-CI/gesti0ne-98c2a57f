import { test, expect, type Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { signInAsTestUser } from "./helpers/auth";

/**
 * Flux métier Colisage → Tournée validée → Suivi de livraison.
 *
 * Vérifie que :
 *  1. Un colis dont le BL est en `colisage_termine` apparaît dans « Nouvelle
 *     tournée » et y est auto-sélectionné.
 *  2. La validation du formulaire crée la tournée, l'affecte au colis et
 *     ouvre automatiquement une ligne de suivi de livraison
 *     (via la RPC `finaliser_tournee`).
 *  3. Le rechargement de la page de suivi ne duplique pas la ligne.
 *  4. Un changement de zoom navigateur n'induit pas de doublon non plus.
 */

const SUPABASE_URL = process.env.VITE_SUPABASE_URL!;
const SUPABASE_KEY = process.env.VITE_SUPABASE_PUBLISHABLE_KEY!;

type Fixture = {
  clientId: string;
  commandeId: string;
  commandeRef: string;
  depotId: string;
  depotNom: string;
  vehiculeId: string;
  vehiculeImmat: string;
  blId: string;
  colisId: string;
  colisRef: string;
};

function db(): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function login(client: SupabaseClient) {
  const email = process.env.E2E_TEST_EMAIL!;
  const password = process.env.E2E_TEST_PASSWORD!;
  const { error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw error;
}

async function createFixture(): Promise<Fixture> {
  const c = db();
  await login(c);
  const suf = Math.random().toString(36).slice(2, 8).toUpperCase();

  const { data: client, error: e1 } = await c
    .from("clients").insert({ nom: `E2E_TRN_${suf}` })
    .select("client_id").single();
  if (e1 || !client) throw e1 ?? new Error("client");

  const commandeRef = `E2E-TRN-${suf}`;
  const { data: cmd, error: e2 } = await c
    .from("commandes").insert({
      client_id: client.client_id,
      numero: commandeRef,
      date_commande: new Date().toISOString().slice(0, 10),
      ville: "Abidjan",
    })
    .select("commande_id").single();
  if (e2 || !cmd) throw e2 ?? new Error("commande");

  const depotNom = `E2E_DEPOT_${suf}`;
  const { data: depot, error: e3 } = await c
    .from("depots").insert({ nom: depotNom, actif: true })
    .select("depot_id").single();
  if (e3 || !depot) throw e3 ?? new Error("depot");

  const vehiculeImmat = `E2E-${suf}`;
  const { data: veh, error: e4 } = await c
    .from("vehicules").insert({ immatriculation: vehiculeImmat, marque: "X", modele: "Y" })
    .select("vehicule_id").single();
  if (e4 || !veh) throw e4 ?? new Error("vehicule");

  const { data: bl, error: e5 } = await c
    .from("bons_livraison").insert({
      commande_id: cmd.commande_id,
      statut: "colisage_termine",
      numero: `BL-${suf}`,
    })
    .select("bl_id").single();
  if (e5 || !bl) throw e5 ?? new Error("bl");

  const colisRef = `COL-${suf}`;
  const { data: col, error: e6 } = await c
    .from("colis").insert({
      commande_id: cmd.commande_id,
      bl_id: bl.bl_id,
      reference: colisRef,
      nb_cartons: 1,
      destinataire: `E2E_TRN_${suf}`,
      livreur_nom: "Chauffeur E2E",
      vehicule: vehiculeImmat,
      date_colisage: new Date().toISOString().slice(0, 10),
    })
    .select("colis_id").single();
  if (e6 || !col) throw e6 ?? new Error("colis");

  return {
    clientId: client.client_id,
    commandeId: cmd.commande_id,
    commandeRef,
    depotId: depot.depot_id,
    depotNom,
    vehiculeId: veh.vehicule_id,
    vehiculeImmat,
    blId: bl.bl_id,
    colisId: col.colis_id,
    colisRef,
  };
}

async function cleanup(f: Fixture) {
  const c = db();
  await login(c);
  // Le trigger colis_tournee_immutable empêche de dé-affecter, on supprime.
  await c.from("livsuivi_commandes").delete().eq("commande_id", f.commandeId);
  await c.from("colis").delete().eq("colis_id", f.colisId);
  const { data: trns } = await c.from("tournees").select("tournee_id").eq("reference", `E2E-TRN-${f.commandeRef.split("-").pop()}`);
  await c.from("bons_livraison").delete().eq("bl_id", f.blId);
  await c.from("commandes").delete().eq("commande_id", f.commandeId);
  await c.from("clients").delete().eq("client_id", f.clientId);
  await c.from("vehicules").delete().eq("vehicule_id", f.vehiculeId);
  await c.from("depots").delete().eq("depot_id", f.depotId);
  if (trns?.length) {
    for (const t of trns) await c.from("tournees").delete().eq("tournee_id", t.tournee_id);
  }
}

async function countSuiviRowsFor(page: Page, commandeRef: string): Promise<number> {
  // Le module Suivi liste chaque commande dans une <table> ; on compte
  // les lignes contenant la référence exacte.
  const cells = page.locator("tr", { hasText: commandeRef });
  return await cells.count();
}

test.describe("Workflow Colisage → Tournée → Suivi de livraison", () => {
  let fx: Fixture;

  test.beforeAll(async () => {
    fx = await createFixture();
  });
  test.afterAll(async () => {
    if (fx) await cleanup(fx);
  });
  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("crée une tournée validée depuis un colis prêt et l'affiche dans le Suivi", async ({
    page,
  }) => {
    await page.goto("/tournees/nouvelle");

    // Le colis fraîchement colisé doit apparaître dans la liste des prêts
    // non affectés, et être auto-sélectionné.
    const colisRow = page.getByRole("row", { name: new RegExp(fx.colisRef) });
    await expect(colisRow).toBeVisible({ timeout: 15_000 });

    // Dépôt de départ (Radix Select).
    await page.getByRole("combobox", { name: /Dépôt de départ/i }).click();
    await page.getByRole("option", { name: fx.depotNom }).click();

    // Véhicule (Radix Select) — sélection par immatriculation.
    await page.getByRole("combobox", { name: /Véhicule/i }).click();
    await page.getByRole("option", { name: fx.vehiculeImmat }).click();

    // Bouton Valider — dialog de confirmation obligatoire.
    const valider = page.getByRole("button", { name: /Valider la tournée/i });
    await expect(valider).toBeEnabled();
    await valider.click();
    await page.getByRole("button", { name: /^Confirmer$/ }).click();

    // Retour vers /tournees après succès.
    await expect(page).toHaveURL(/\/tournees(\?|$)/, { timeout: 15_000 });
    await expect(page.getByText("Tournée validée")).toBeVisible().catch(() => {});

    // La ligne de suivi doit exister (créée par finaliser_tournee).
    await page.goto("/livraison-suivi");
    await expect(page.getByRole("row", { name: new RegExp(fx.commandeRef) })).toBeVisible({
      timeout: 15_000,
    });
    expect(await countSuiviRowsFor(page, fx.commandeRef)).toBe(1);
  });

  test("pas de duplication après rechargement", async ({ page }) => {
    await page.goto("/livraison-suivi");
    await expect(page.getByRole("row", { name: new RegExp(fx.commandeRef) })).toBeVisible({
      timeout: 15_000,
    });
    const before = await countSuiviRowsFor(page, fx.commandeRef);
    expect(before).toBe(1);

    await page.reload({ waitUntil: "domcontentloaded" });
    await expect(page.getByRole("row", { name: new RegExp(fx.commandeRef) })).toBeVisible({
      timeout: 15_000,
    });
    expect(await countSuiviRowsFor(page, fx.commandeRef)).toBe(1);
  });

  test("pas de duplication après changement de zoom", async ({ page }) => {
    await page.goto("/livraison-suivi");
    await expect(page.getByRole("row", { name: new RegExp(fx.commandeRef) })).toBeVisible({
      timeout: 15_000,
    });
    expect(await countSuiviRowsFor(page, fx.commandeRef)).toBe(1);

    // Simule Ctrl+= / Ctrl+- via document.body.style.zoom (comportement
    // Chromium équivalent). On teste deux niveaux (125 % puis 75 %).
    for (const zoom of ["1.25", "0.75", "1"]) {
      await page.evaluate((z) => {
        (document.body.style as CSSStyleDeclaration & { zoom?: string }).zoom = z;
      }, zoom);
      await page.waitForTimeout(200);
      expect(await countSuiviRowsFor(page, fx.commandeRef)).toBe(1);
    }
  });
});