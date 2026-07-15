/**
 * Cache local du user courant — évite un round-trip réseau à chaque appel.
 *
 * `supabase.auth.getUser()` frappe l'API `/user` de GoTrue (5-50 ms).
 * `supabase.auth.getSession()` lit uniquement le localStorage (synchrone après
 * hydratation). Pour un ERP interne où l'identité utilisateur est déjà validée
 * par le middleware serveur (`requireSupabaseAuth`) et le gate `_authenticated`,
 * lire la session locale est suffisant côté client.
 */
import type { supabase as SupabaseClient } from "@/integrations/supabase/client";

type SupabaseBrowserClient = typeof SupabaseClient;

let cachedUserId: string | null | undefined;
let cachedUserEmail: string | null | undefined;
let initPromise: Promise<void> | undefined;

async function getSupabase(): Promise<SupabaseBrowserClient> {
  const module = await import("@/integrations/supabase/client");
  return module.supabase;
}

function initCurrentUserCache() {
  if (typeof window === "undefined") return;
  if (initPromise) return;

  initPromise = getSupabase()
    .then(async (supabase) => {
      const { data } = await supabase.auth.getSession();
      cachedUserId = data.session?.user?.id ?? null;
      cachedUserEmail = data.session?.user?.email ?? null;
      supabase.auth.onAuthStateChange((_event, session) => {
        cachedUserId = session?.user?.id ?? null;
        cachedUserEmail = session?.user?.email ?? null;
      });
    })
    .catch((error) => {
      console.error("[current-user] Impossible d'initialiser la session locale", error);
      cachedUserId = null;
      cachedUserEmail = null;
    });
}

async function refreshCurrentUserCache(): Promise<void> {
  try {
    const supabase = await getSupabase();
    const { data } = await supabase.auth.getSession();
    cachedUserId = data.session?.user?.id ?? null;
    cachedUserEmail = data.session?.user?.email ?? null;
  } catch (error) {
    console.error("[current-user] Impossible de lire la session locale", error);
    cachedUserId = null;
    cachedUserEmail = null;
  }
}

// Écoute unique : maintient le cache à jour sans refetch.
initCurrentUserCache();

/** ID de l'utilisateur courant, depuis la session locale (aucun réseau). */
export async function getCurrentUserId(): Promise<string | null> {
  if (cachedUserId !== undefined) return cachedUserId;
  await refreshCurrentUserCache();
  return cachedUserId ?? null;
}

/** Email de l'utilisateur courant, depuis la session locale. */
export async function getCurrentUserEmail(): Promise<string | null> {
  if (cachedUserEmail !== undefined) return cachedUserEmail;
  await refreshCurrentUserCache();
  return cachedUserEmail ?? null;
}

/** Retourne `{ data: { user } }` compatible avec l'API historique. */
export async function getCurrentUser(): Promise<{
  data: { user: { id: string; email: string | null } | null };
}> {
  const id = await getCurrentUserId();
  if (!id) return { data: { user: null } };
  const email = await getCurrentUserEmail();
  return { data: { user: { id, email } } };
}
