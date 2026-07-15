/**
 * Cache mémoire des Blob PDF générés. Évite de regénérer le PDF
 * quand l'utilisateur enchaîne Visualiser → Télécharger → Imprimer
 * sur le même document. Invalidation manuelle via `invalidatePdf(key)`
 * et limite LRU souple (50 entrées).
 */

type Entry = { blob: Blob; ts: number };

const MAX = 50;
const TTL_MS = 5 * 60 * 1000; // 5 min
const store = new Map<string, Entry>();

/** Métriques globales pour repérer la latence Visualiser/Télécharger/Imprimer. */
export const pdfCacheMetrics = {
  hits: 0,
  misses: 0,
  totalGenMs: 0,
  lastGenMs: 0,
  lastKey: "" as string,
};

const DEBUG =
  typeof window !== "undefined" &&
  (localStorage.getItem("pdfCacheDebug") === "1" || import.meta.env?.DEV);

function evict() {
  if (store.size <= MAX) return;
  const oldest = [...store.entries()].sort((a, b) => a[1].ts - b[1].ts)[0]?.[0];
  if (oldest) store.delete(oldest);
}

/**
 * Renvoie le blob en cache pour `key`, sinon appelle `factory()` puis met
 * en cache. La clé doit inclure une version (updated_at) pour invalider
 * automatiquement lors d'une modification du document.
 */
export async function getOrCreatePdf(key: string, factory: () => Promise<Blob>): Promise<Blob> {
  const t0 = performance.now();
  const hit = store.get(key);
  if (hit && Date.now() - hit.ts < TTL_MS) {
    pdfCacheMetrics.hits++;
    pdfCacheMetrics.lastKey = key;
    if (DEBUG) console.debug(`[pdfCache] HIT ${key} (${(performance.now() - t0).toFixed(1)}ms)`);
    return hit.blob;
  }
  pdfCacheMetrics.misses++;
  const blob = await factory();
  const ms = performance.now() - t0;
  pdfCacheMetrics.lastGenMs = ms;
  pdfCacheMetrics.totalGenMs += ms;
  pdfCacheMetrics.lastKey = key;
  store.set(key, { blob, ts: Date.now() });
  evict();
  if (DEBUG) console.debug(`[pdfCache] MISS ${key} generated in ${ms.toFixed(1)}ms`);
  return blob;
}

export function invalidatePdf(key: string): void {
  store.delete(key);
}

/**
 * Invalide toutes les entrées dont la clé commence par `prefix`.
 * Utile quand on connaît le type+référence mais pas la version exacte,
 * ou pour purger toutes les versions antérieures après un updated_at.
 */
export function invalidatePdfByPrefix(prefix: string): number {
  let n = 0;
  for (const k of [...store.keys()]) {
    if (k.startsWith(prefix)) {
      store.delete(k);
      n++;
    }
  }
  return n;
}

export function clearPdfCache(): void {
  store.clear();
}

/** Construit une clé stable à partir d'un type + référence + version. */
export function pdfCacheKey(type: string, reference: string, version?: string | number | null) {
  return `${type}:${reference}:${version ?? "v0"}`;
}

/** Préfixe (type:reference:) — pratique pour invalidatePdfByPrefix. */
export function pdfCacheKeyPrefix(type: string, reference: string) {
  return `${type}:${reference}:`;
}
