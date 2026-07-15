import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.VITE_SUPABASE_URL!;
const SUPABASE_KEY = process.env.VITE_SUPABASE_PUBLISHABLE_KEY!;

export type RemiseFixture = {
  clientId: string;
  commandeId: string;
  commandeRef: string;
  colisId: string | null;
  livraisonId: string;
};

function makeClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function login(client: SupabaseClient): Promise<void> {
  const email = process.env.E2E_TEST_EMAIL!;
  const password = process.env.E2E_TEST_PASSWORD!;
  const { error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw error;
}

/**
 * Crée un jeu complet client + commande + colis + livsuivi_commandes.
 * `withLivreur=false` retire le nom du livreur pour exercer le cas
 * « données incomplètes » (bouton désactivé + alerte).
 */
export async function createRemiseFixture(opts: {
  withColis: boolean;
  withLivreur: boolean;
  type?: "direct" | "expedition";
}): Promise<RemiseFixture> {
  const client = makeClient();
  await login(client);

  const suffix = Math.random().toString(36).slice(2, 8).toUpperCase();
  const commandeRef = `E2E-REMISE-${suffix}`;

  const { data: c, error: eC } = await client
    .from("clients")
    .insert({ nom: `E2E_CLIENT_${suffix}` })
    .select("client_id")
    .single();
  if (eC || !c) throw eC ?? new Error("client insert failed");

  const { data: cmd, error: eCmd } = await client
    .from("commandes")
    .insert({
      client_id: c.client_id,
      numero: commandeRef,
      date_commande: new Date().toISOString().slice(0, 10),
      adresse: "12 rue de test",
      ville: "Abidjan",
    })
    .select("commande_id")
    .single();
  if (eCmd || !cmd) throw eCmd ?? new Error("commande insert failed");

  let colisId: string | null = null;
  if (opts.withColis) {
    const { data: colis, error: eColis } = await client
      .from("colis")
      .insert({
        commande_id: cmd.commande_id,
        reference: `COL-${suffix}`,
        nb_colis: 1,
        nb_cartons: 1,
        destinataire: `E2E_CLIENT_${suffix}`,
        livreur_nom: opts.withLivreur ? "Livreur E2E" : null,
      })
      .select("colis_id")
      .single();
    if (eColis || !colis) throw eColis ?? new Error("colis insert failed");
    colisId = colis.colis_id;
  }

  const { data: liv, error: eLiv } = await client
    .from("livsuivi_commandes")
    .insert({
      commande_id: cmd.commande_id,
      type_livraison: opts.type ?? "direct",
      statut: "preparee",
      livreur_nom: opts.withLivreur ? "Livreur E2E" : null,
    })
    .select("id")
    .single();
  if (eLiv || !liv) throw eLiv ?? new Error("livsuivi_commandes insert failed");

  return {
    clientId: c.client_id,
    commandeId: cmd.commande_id,
    commandeRef,
    colisId,
    livraisonId: liv.id,
  };
}

export async function deleteRemiseFixture(f: RemiseFixture): Promise<void> {
  const client = makeClient();
  await login(client);
  if (f.colisId) await client.from("colis").delete().eq("colis_id", f.colisId);
  await client.from("commandes").delete().eq("commande_id", f.commandeId);
  await client.from("clients").delete().eq("client_id", f.clientId);
}