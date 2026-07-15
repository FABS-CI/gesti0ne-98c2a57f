/**
 * Politique de persistance de session en fonction du choix "Se souvenir de moi".
 *
 * - remember = true  : le token Supabase reste dans localStorage (persistance
 *   durable, y compris après fermeture de l'APK / du navigateur).
 * - remember = false : on installe un handler qui purge le token à la fermeture
 *   de la page (pagehide) pour que la session ne survive pas à la prochaine
 *   ouverture de l'APK.
 *
 * Idempotent : les handlers précédents sont retirés avant chaque application.
 */

const FLAG_KEY = "auth:remember";
let installedHandler: ((this: Window, ev: Event) => void) | null = null;

function clearSupabaseAuthTokens() {
  try {
    for (let i = window.localStorage.length - 1; i >= 0; i -= 1) {
      const key = window.localStorage.key(i);
      if (key?.startsWith("sb-") && key.endsWith("-auth-token")) {
        window.localStorage.removeItem(key);
      }
    }
  } catch {
    /* ignore */
  }
}

export function applyRememberPolicy(remember: boolean) {
  if (typeof window === "undefined") return;

  try {
    window.localStorage.setItem(FLAG_KEY, remember ? "1" : "0");
  } catch {
    /* ignore */
  }

  if (installedHandler) {
    window.removeEventListener("pagehide", installedHandler);
    installedHandler = null;
  }

  if (!remember) {
    installedHandler = () => clearSupabaseAuthTokens();
    window.addEventListener("pagehide", installedHandler);
  }
}

/**
 * À appeler au démarrage : si l'utilisateur avait décoché "Se souvenir de moi"
 * lors d'une session précédente, on réinstalle le handler de purge.
 */
export function initRememberPolicyFromStorage() {
  if (typeof window === "undefined") return;
  try {
    const flag = window.localStorage.getItem(FLAG_KEY);
    if (flag === "0") applyRememberPolicy(false);
  } catch {
    /* ignore */
  }
}