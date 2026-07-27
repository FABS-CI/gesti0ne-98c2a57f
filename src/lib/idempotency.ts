/**
 * Clé d'idempotence : évite la création de doublons quand une même saisie
 * est envoyée plusieurs fois (double-clic, réseau instable, retry).
 * La clé est générée une fois par session de saisie et transmise au RPC,
 * qui renvoie le document déjà créé au lieu d'en créer un second.
 */
export function newIdempotencyKey(prefix = "doc"): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}
