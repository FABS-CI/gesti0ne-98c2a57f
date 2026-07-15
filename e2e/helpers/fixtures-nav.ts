import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.VITE_SUPABASE_URL!;
const SUPABASE_KEY = process.env.VITE_SUPABASE_PUBLISHABLE_KEY!;

function makeClient(): SupabaseClient {
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

/**
 * Garantit qu'au moins un exercice existe pour peupler les listes
 * `/exercices` et `/exercices/comparatif`. Idempotent : s'il en existe
 * déjà, ne fait rien. Sinon insère un exercice E2E daté sur l'année
 * courante avec statut `preparation` (n'interfère pas avec l'actif).
 */
export async function ensureAtLeastOneExercice(): Promise<void> {
  const client = makeClient();
  await login(client);
  const { data, error } = await client
    .from("exercices")
    .select("exercice_id")
    .limit(1);
  if (error) throw error;
  if (data && data.length > 0) return;

  const year = new Date().getUTCFullYear();
  const { error: eIns } = await client.from("exercices").insert({
    code: `E2E-${year}`,
    date_debut: `${year}-01-01`,
    date_fin: `${year}-12-31`,
    statut: "preparation",
    is_actif: false,
  });
  if (eIns) throw eIns;
}

/**
 * Garantit qu'au moins une commande de suivi apparaît dans la liste
 * `/livraison-suivi`. Réutilise la même mécanique que `createRemiseFixture`
 * (insert client + commande + livsuivi_commandes) mais idempotent.
 * Retourne la commande.numero utilisée par la ligne.
 */
export async function ensureAtLeastOneLivraisonSuivi(): Promise<string> {
  const client = makeClient();
  await login(client);
  const { data, error } = await client
    .from("livsuivi_commandes")
    .select("commande_id, commandes:commandes!inner(numero)")
    .limit(1);
  if (error) throw error;
  if (data && data.length > 0) {
    // @ts-expect-error alias join
    return data[0].commandes.numero as string;
  }

  const suffix = Math.random().toString(36).slice(2, 8).toUpperCase();
  const commandeRef = `E2E-NAV-${suffix}`;
  const { data: c, error: eC } = await client
    .from("clients")
    .insert({ nom: `E2E_NAV_${suffix}` })
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

  const { error: eLiv } = await client.from("livsuivi_commandes").insert({
    commande_id: cmd.commande_id,
    type_livraison: "direct",
    statut: "preparee",
    livreur_nom: "Livreur E2E NAV",
  });
  if (eLiv) throw eLiv;

  return commandeRef;
}