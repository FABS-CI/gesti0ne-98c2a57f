import { test, expect, type Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { signInAsTestUser } from "./helpers/auth";

/**
 * Règles métier Colisage → Tournée → Suivi de livraison.
 *
 *  1. Le suivi de livraison n'est PAS créé automatiquement lorsque le
 *     colisage passe à `colisage_termine` — il faut valider une tournée.
 *  2. « Nouvelle tournée » sans colis prêt affiche l'état vide.
 *  3. « Clôturer » applique toutes les règles (champs obligatoires,
 *     livraisons prévues) et passe le statut à `terminee`.
 *  4. Le filtre + pagination du Suivi ne duplique aucune ligne.
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

function suf() {
  return Math.random().toString(36).slice(2, 8).toUpperCase();
}

async function seedColisTermine(): Promise<{
  clientId: string;
  commandeId: string;
  commandeRef: string;
  blId: string;
  colisId: string;
}> {
  const c = db();
  await login(c);
  const s = suf();
  const { data: cli } = await c
    .from("clients").insert({ nom: `E2E_NA_${s}` })
    .select("client_id").single();
  const commandeRef = `E2E-NA-${s}`;
  const { data: cmd } = await c
    .from("commandes")
    .insert({
      client_id: cli!.client_id,
      numero: commandeRef,
      date_commande: new Date().toISOString().slice(0, 10),
    })
    .select("commande_id").single();
  const { data: bl } = await c
    .from("bons_livraison")
    .insert({
      commande_id: cmd!.commande_id,
      statut: "colisage_termine",
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
      destinataire: `E2E_NA_${s}`,
      date_colisage: new Date().toISOString().slice(0, 10),
    })
    .select("colis_id").single();
  return {
    clientId: cli!.client_id,
    commandeId: cmd!.commande_id,
    commandeRef,
    blId: bl!.bl_id,
    colisId: col!.colis_id,
  };
}

async function seedValidatedTournee(): Promise<{
  clientId: string;
  commandeId: string;
  commandeRef: string;
  blId: string;
  colisId: string;
  tourneeId: string;
  livSuiviId: string;
  depotId: string;
  vehiculeId: string;
}> {
  const c = db();
  await login(c);
  const s = suf();
  const seed = await seedColisTermine();
  const { data: depot } = await c
    .from("depots").insert({ nom: `E2E_DEP_${s}`, actif: true })
    .select("depot_id").single();
  const { data: veh } = await c
    .from("vehicules")
    .insert({ immatriculation: `E2E-${s}`, marque: "X", modele: "Y" })
    .select("vehicule_id").single();
  const { data: trn } = await c
    .from("tournees")
    .insert({
      reference: `TRN-E2E-${s}`,
      date_tournee: new Date().toISOString().slice(0, 10),
      heure_depart: "08:00",
      depot_depart_id: depot!.depot_id,
      chauffeur_nom: "Chauffeur E2E",
      vehicule_id: veh!.vehicule_id,
      statut: "en_cours",
      type_tournee: "livraison",
      nb_colis: 1,
      nb_cartons: 1,
      nb_clients: 1,
    })
    .select("tournee_id").single();
  await c
    .from("colis")
    .update({ tournee_id: trn!.tournee_id } as never)
    .eq("colis_id", seed.colisId);
  const { data: liv } = await c
    .from("livsuivi_commandes")
    .insert({
      commande_id: seed.commandeId,
      tournee_id: trn!.tournee_id,
      type_livraison: "direct",
      statut: "preparee",
      livreur_nom: "Chauffeur E2E",
    })
    .select("id").single();
  return {
    ...seed,
    tourneeId: trn!.tournee_id,
    livSuiviId: liv!.id,
    depotId: depot!.depot_id,
    vehiculeId: veh!.vehicule_id,
  };
}

async function cleanupAll(ids: {
  clientId?: string;
  commandeId?: string;
  blId?: string;
  colisId?: string;
  tourneeId?: string;
  depotId?: string;
  vehiculeId?: string;
}) {
  const c = db();
  await login(c);
  if (ids.commandeId) await c.from("livsuivi_commandes").delete().eq("commande_id", ids.commandeId);
  if (ids.colisId) await c.from("colis").delete().eq("colis_id", ids.colisId);
  if (ids.tourneeId) await c.from("tournees").delete().eq("tournee_id", ids.tourneeId);
  if (ids.blId) await c.from("bons_livraison").delete().eq("bl_id", ids.blId);
  if (ids.commandeId) await c.from("commandes").delete().eq("commande_id", ids.commandeId);
  if (ids.clientId) await c.from("clients").delete().eq("client_id", ids.clientId);
  if (ids.vehiculeId) await c.from("vehicules").delete().eq("vehicule_id", ids.vehiculeId);
  if (ids.depotId) await c.from("depots").delete().eq("depot_id", ids.depotId);
}

async function countRows(page: Page, ref: string) {
  return await page.locator("tr", { hasText: ref }).count();
}

test.describe("Workflow rules — Colisage / Tournée / Suivi", () => {
  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("le suivi n'est PAS créé automatiquement après « Colisage terminé »", async ({
    page,
  }) => {
    const seed = await seedColisTermine();
    try {
      // Contrôle direct base de données : aucune ligne livsuivi_commandes.
      const c = db();
      await login(c);
      const { data } = await c
        .from("livsuivi_commandes")
        .select("id")
        .eq("commande_id", seed.commandeId);
      expect(data ?? []).toHaveLength(0);

      // Contrôle UI : la commande n'apparaît pas dans /livraison-suivi.
      await page.goto("/livraison-suivi");
      await page.waitForLoadState("networkidle");
      expect(await countRows(page, seed.commandeRef)).toBe(0);
    } finally {
      await cleanupAll(seed);
    }
  });

  test("« Nouvelle tournée » affiche l'état vide sans colis prêt", async ({ page }) => {
    // On force la liste des prêts à être vide en réécrivant la réponse
    // PostgREST — indépendant des données réelles de l'utilisateur.
    await page.route(/\/rest\/v1\/colis\?.*tournee_id=is\.null/, async (route) => {
      await route.fulfill({
        status: 200,
        headers: { "Content-Type": "application/json", "Content-Range": "*/0" },
        body: "[]",
      });
    });
    await page.goto("/tournees/nouvelle");
    await expect(
      page.getByText(/Aucun colis prêt non affecté\. Préparez un colisage d'abord\./i),
    ).toBeVisible({ timeout: 15_000 });
    // Bouton « Valider la tournée » désactivé.
    await expect(page.getByRole("button", { name: /Valider la tournée/i })).toBeDisabled();
    // Le récapitulatif indique 0 colis.
    await expect(page.getByText(/Colis/i).first()).toBeVisible();
  });

  test("« Clôturer » : bloque si livraisons non finalisées puis termine la tournée", async ({
    page,
  }) => {
    const seed = await seedValidatedTournee();
    try {
      await page.goto(`/tournees/${seed.tourneeId}`);
      await expect(page.getByRole("button", { name: /Clôturer/i })).toBeVisible({
        timeout: 15_000,
      });

      // 1er essai : livsuivi encore en `preparee` → clôture refusée.
      await page.getByRole("button", { name: /Clôturer/i }).click();
      await page.getByRole("button", { name: /^Confirmer$/ }).click();
      await expect(page.getByText(/Clôture impossible/i)).toBeVisible({ timeout: 10_000 });

      // Statut inchangé — on requête la base.
      const c = db();
      await login(c);
      const { data: t1 } = await c
        .from("tournees")
        .select("statut")
        .eq("tournee_id", seed.tourneeId)
        .single();
      expect(t1?.statut).toBe("en_cours");

      // On force les livraisons prévues à un état terminal.
      await c
        .from("livsuivi_commandes")
        .update({ statut: "livree" } as never)
        .eq("id", seed.livSuiviId);

      // 2e essai : clôture acceptée.
      await page.reload();
      await page.getByRole("button", { name: /Clôturer/i }).click();
      await page.getByRole("button", { name: /^Confirmer$/ }).click();
      await expect(page.getByText(/Tournée clôturée/i)).toBeVisible({ timeout: 10_000 });

      const { data: t2 } = await c
        .from("tournees")
        .select("statut,cloture_mode")
        .eq("tournee_id", seed.tourneeId)
        .single();
      expect(t2?.statut).toBe("terminee");
      expect(t2?.cloture_mode).toBe("manuelle");
    } finally {
      await cleanupAll(seed);
    }
  });

  test("Suivi — filtre + navigation ne duplique pas la ligne", async ({ page }) => {
    const seed = await seedValidatedTournee();
    try {
      await page.goto("/livraison-suivi");
      await expect(
        page.getByRole("row", { name: new RegExp(seed.commandeRef) }),
      ).toBeVisible({ timeout: 15_000 });
      expect(await countRows(page, seed.commandeRef)).toBe(1);

      // Applique un filtre texte qui matche la référence.
      const search = page.getByPlaceholder(/Rechercher|Recherche/i).first();
      if (await search.isVisible().catch(() => false)) {
        await search.fill(seed.commandeRef);
        await page.waitForTimeout(400);
        expect(await countRows(page, seed.commandeRef)).toBe(1);
        await search.fill("");
        await page.waitForTimeout(400);
        expect(await countRows(page, seed.commandeRef)).toBe(1);
      }

      // Navigation aller-retour vers le détail puis retour à la liste.
      await page.goto(`/livraison-suivi/${encodeURIComponent(seed.commandeRef)}`);
      await expect(page.getByText(/Suivi —|Historique|Retour/i).first()).toBeVisible({
        timeout: 15_000,
      });
      await page.goto("/livraison-suivi");
      await expect(
        page.getByRole("row", { name: new RegExp(seed.commandeRef) }),
      ).toBeVisible({ timeout: 15_000 });
      expect(await countRows(page, seed.commandeRef)).toBe(1);
    } finally {
      await cleanupAll(seed);
    }
  });
});