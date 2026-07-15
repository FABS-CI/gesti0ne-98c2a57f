import { logAuditEvent, type AuditEventInput } from "@/lib/audit.functions";

/**
 * Client wrapper: appelle le serverFn logAuditEvent sans jamais bloquer l'UI.
 * Toute erreur est avalée (le journal ne doit pas faire tomber l'écran).
 */
export function audit(input: AuditEventInput) {
  void logAuditEvent({ data: input }).catch((e) => {
    if (import.meta.env.DEV) console.warn("[audit] échec:", e);
  });
}
