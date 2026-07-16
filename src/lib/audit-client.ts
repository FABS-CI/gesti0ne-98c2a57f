import { logAuditEvent, type AuditEventInput } from "@/lib/audit.functions";

/**
 * Identifiant de session généré une fois par onglet (persisté en sessionStorage).
 * Sert à corréler tous les événements d'une même session utilisateur.
 */
function getSessionId(): string | undefined {
  if (typeof window === "undefined") return undefined;
  try {
    let s = sessionStorage.getItem("__audit_session_id");
    if (!s) {
      s = crypto.randomUUID();
      sessionStorage.setItem("__audit_session_id", s);
    }
    return s;
  } catch {
    return undefined;
  }
}

/**
 * Enrichit chaque événement avec le contexte navigateur (URL, méthode implicite,
 * résolution, fuseau, session, corrélation), puis envoie au serverFn.
 * Ne bloque jamais l'UI ; les erreurs sont avalées.
 */
export function audit(input: AuditEventInput) {
  const enriched: AuditEventInput = { ...input };
  if (typeof window !== "undefined") {
    try {
      enriched.url = enriched.url ?? window.location.pathname + window.location.search;
      enriched.session_id = enriched.session_id ?? getSessionId();
      enriched.correlation_id = enriched.correlation_id ?? crypto.randomUUID();
      enriched.screen_resolution =
        enriched.screen_resolution ?? `${window.screen.width}x${window.screen.height}`;
      enriched.timezone = enriched.timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone;
    } catch {
      // silencieux
    }
  }
  void logAuditEvent({ data: enriched }).catch((e) => {
    if (import.meta.env.DEV) console.warn("[audit] échec:", e);
  });
}
