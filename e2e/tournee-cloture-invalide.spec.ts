import { test, expect } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { signInAsTestUser } from "./helpers/auth";

/**
 * Vérifie les messages d'erreur (toast Sonner) quand une clôture de tournée
 * est refusée pour :
 *   a) champs obligatoires manquants (chauffeur absent) ;
 *   b) livraisons prévues non terminales (statut `preparee`).
 *
 * Dans les deux cas :
 *   - un toast « Clôture impossible » apparaît avec le motif ;
 *   - le statut de la tournée reste inchangé (`en_cours`).
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

type Ids = {
  clientId: string;
  commandeId: string;
  blId: string;
  colisId: string;
  depotId: string;
  vehiculeId: string;
  tourneeId: string;
  livSuiviId: string;
};

async function seed(opts: { chauffeur: boolean; livraisonTerminee: boolean }): Promise<Ids> {
  const c = db();
  await login(c);
  const s = suf();
  const { data: cli } = await c
    .from("clients").insert({ nom: `E2E_CLO_${s}` })
    .select("client_id").single();
  const { data: cmd } = await c
    .from("commandes")
    .insert({
      client_id: cli!.client_id,
      numero: `E2E-CLO-${s}`,
      date_commande: new Date().toISOString().slice(0, 10),
    })
    .select("commande_id").single();
  const { data: bl } = await c
    .from("bons_livraison")
    .insert({ commande_id: cmd!.commande_id, statut: "colisage_termine", numero: `BL-${s}` })
    .select("bl_id").single();
  const { data: col } = await c
    .from("colis")
    .insert({
      commande_id: cmd!.commande_id,
      bl_id: bl!.bl_id,
      reference: `COL-${s}`,
      nb_cartons: 1,
      destinataire: `E2E_CLO_${s}`,
      date_colisage: new Date().toISOString().slice(0, 10),
    })
    .select("colis_id").single();
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
      reference: `TRN-CLO-${s}`,
      date_tournee: new Date().toISOString().slice(0, 10),
      heure_depart: "08:00",
      depot_depart_id: depot!.depot_id,
      chauffeur_nom: opts.chauffeur ? "Chauffeur E2E" : null,
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
    .eq("colis_id", col!.colis_id);
  const { data: liv } = await c
    .from("livsuivi_commandes")
    .insert({
      commande_id: cmd!.commande_id,
      tournee_id: trn!.tournee_id,
      type_livraison: "direct",
      statut: opts.livraisonTerminee ? "livree" : "preparee",
      livreur_nom: "Chauffeur E2E",
    })
    .select("id").single();
  return {
    clientId: cli!.client_id,
    commandeId: cmd!.commande_id,
    blId: bl!.bl_id,
    colisId: col!.colis_id,
    depotId: depot!.depot_id,
    vehiculeId: veh!.vehicule_id,
    tourneeId: trn!.tournee_id,
    livSuiviId: liv!.id,
  };
}

async function cleanup(ids: Ids) {
  const c = db();
  await login(c);
  await c.from("livsuivi_commandes").delete().eq("id", ids.livSuiviId);
  await c.from("colis").delete().eq("colis_id", ids.colisId);
  await c.from("tournees").delete().eq("tournee_id", ids.tourneeId);
  await c.from("bons_livraison").delete().eq("bl_id", ids.blId);
  await c.from("commandes").delete().eq("commande_id", ids.commandeId);
  await c.from("clients").delete().eq("client_id", ids.clientId);
  await c.from("vehicules").delete().eq("vehicule_id", ids.vehiculeId);
  await c.from("depots").delete().eq("depot_id", ids.depotId);
}

async function assertStatutInchange(tourneeId: string) {
  const c = db();
  await login(c);
  const { data } = await c
    .from("tournees").select("statut").eq("tournee_id", tourneeId).single();
  expect(data?.statut).toBe("en_cours");
}

test.describe("Clôture tournée — règles invalides", () => {
  test.beforeEach(async ({ page }) => {
    await signInAsTestUser(page);
  });

  test("champ obligatoire manquant (Chauffeur) → toast d'erreur", async ({ page }) => {
    const ids = await seed({ chauffeur: false, livraisonTerminee: true });
    try {
      await page.goto(`/tournees/${ids.tourneeId}`);
      await page.getByRole("button", { name: /Clôturer/i }).click();
      await page.getByRole("button", { name: /^Confirmer$/ }).click();

      const toast = page.getByText(/Clôture impossible/i);
      await expect(toast).toBeVisible({ timeout: 10_000 });
      await expect(page.getByText(/Informations manquantes.*Chauffeur/i)).toBeVisible();

      await assertStatutInchange(ids.tourneeId);
    } finally {
      await cleanup(ids);
    }
  });

  test("livraison non terminale (statut « preparee ») → toast d'erreur", async ({ page }) => {
    const ids = await seed({ chauffeur: true, livraisonTerminee: false });
    try {
      await page.goto(`/tournees/${ids.tourneeId}`);
      await page.getByRole("button", { name: /Clôturer/i }).click();
      await page.getByRole("button", { name: /^Confirmer$/ }).click();

      await expect(page.getByText(/Clôture impossible/i)).toBeVisible({ timeout: 10_000 });
      await expect(
        page.getByText(/livraison\(s\) ne sont pas encore finalisées/i),
      ).toBeVisible();

      await assertStatutInchange(ids.tourneeId);
    } finally {
      await cleanup(ids);
    }
  });
});