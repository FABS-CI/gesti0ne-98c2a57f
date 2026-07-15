import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const URL = process.env.VITE_SUPABASE_URL ?? process.env.SUPABASE_URL;
const KEY = process.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? process.env.SUPABASE_PUBLISHABLE_KEY;
const ACCESS_TOKEN = process.env.LOVABLE_BROWSER_SUPABASE_ACCESS_TOKEN;

export const hasAuthSession =
  process.env.LOVABLE_BROWSER_AUTH_STATUS === "injected" &&
  !!ACCESS_TOKEN && !!URL && !!KEY;

let cached: SupabaseClient | null = null;

export function getAuthedClient(): SupabaseClient {
  if (!hasAuthSession) throw new Error("No injected Supabase session for e2e tests");
  if (cached) return cached;
  cached = createClient(URL!, KEY!, {
    auth: { persistSession: false, autoRefreshToken: false, storage: undefined },
    global: { headers: { Authorization: `Bearer ${ACCESS_TOKEN}` } },
  });
  return cached;
}

// Fixture control helpers ---------------------------------------------------

export const FIXTURE_IDS = {
  client: "11111111-1111-1111-1111-111111111111",
  facture: "22222222-2222-2222-2222-222222222222",
  bl: "33333333-3333-3333-3333-333333333333",
  colis1: "44444444-4444-4444-4444-444444444444",
  colis2: "55555555-5555-5555-5555-555555555555",
} as const;

export async function resetFixtures() {
  const { error } = await getAuthedClient().rpc("e2e_reset");
  if (error) throw error;
}

export async function setFacturePaye(montant: number): Promise<string> {
  const { data, error } = await getAuthedClient().rpc("e2e_set_facture_paye", { montant });
  if (error) throw error;
  return data as string;
}

export async function setFactureStatut(statut: string): Promise<string> {
  const { data, error } = await getAuthedClient().rpc("e2e_set_facture_statut", {
    nouveau_statut: statut,
  });
  if (error) throw error;
  return data as string;
}

export async function setColisLivre(numero: 1 | 2) {
  const { error } = await getAuthedClient().rpc("e2e_set_colis_livre", { numero });
  if (error) throw error;
}

export async function getFactureFixture() {
  const { data, error } = await getAuthedClient().rpc("e2e_get_facture");
  if (error) throw error;
  return (data as Array<{ statut: string; montant_paye: number; montant_total: number }>)[0];
}

export async function getBlFixture() {
  const { data, error } = await getAuthedClient().rpc("e2e_get_bl");
  if (error) throw error;
  return (data as Array<{ statut: string; date_livraison: string | null }>)[0];
}