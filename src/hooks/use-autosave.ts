import { useCallback, useEffect, useRef, useState } from "react";

/**
 * useAutosave — sauvegarde automatique d'un brouillon avec anti-perte.
 *
 * Persiste `value` dans localStorage sous `storageKey` avec un debounce.
 * Expose des helpers pour restaurer, effacer, et détecter un conflit
 * (brouillon plus récent qu'une valeur "serveur" fournie).
 *
 * Usage typique :
 *   const { restored, clear, hasDraft, draft } = useAutosave({
 *     storageKey: `commande-draft-${id ?? "new"}`,
 *     value: formValues,
 *     enabled: !isSubmitting,
 *   });
 *
 * Règles :
 * - Ne PAS utiliser pour les flux transactionnels (paiements, validations
 *   comptables). Uniquement pour formulaires longs (commandes, clients,
 *   fiches RH, notes CRM).
 * - Nettoyer avec `clear()` après un submit réussi.
 */

export type AutosaveOptions<T> = {
  storageKey: string;
  value: T;
  /** ms de debounce (défaut 800). */
  debounceMs?: number;
  /** Désactive l'autosave (pendant submit / après succès). */
  enabled?: boolean;
  /** Filtre les valeurs "vides" pour éviter d'écraser un draft utile. */
  isEmpty?: (v: T) => boolean;
};

export type AutosaveState<T> = {
  /** Brouillon présent au montage (avant tout write de la session). */
  draft: T | null;
  /** Timestamp du brouillon initial. */
  draftAt: number | null;
  /** Un brouillon existe. */
  hasDraft: boolean;
  /** Efface le brouillon (localStorage + état). */
  clear: () => void;
  /** Recharge le brouillon si l'utilisateur l'accepte. */
  restore: () => T | null;
  /** État de sauvegarde courant. */
  status: "idle" | "saving" | "saved" | "error";
  /** Dernier timestamp de sauvegarde réussie. */
  savedAt: number | null;
};

type Envelope<T> = { v: T; t: number };

export function useAutosave<T>({
  storageKey,
  value,
  debounceMs = 800,
  enabled = true,
  isEmpty,
}: AutosaveOptions<T>): AutosaveState<T> {
  const [status, setStatus] = useState<AutosaveState<T>["status"]>("idle");
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [initial, setInitial] = useState<Envelope<T> | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastSerialized = useRef<string | null>(null);

  // Restaure au montage
  useEffect(() => {
    if (typeof window === "undefined") return;
    try {
      const raw = window.localStorage.getItem(storageKey);
      if (!raw) return;
      const parsed = JSON.parse(raw) as Envelope<T>;
      if (parsed && typeof parsed.t === "number") setInitial(parsed);
    } catch {
      /* ignore corrupted draft */
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storageKey]);

  // Autosave debounced
  useEffect(() => {
    if (!enabled || typeof window === "undefined") return;
    if (isEmpty?.(value)) return;
    const serialized = safeStringify(value);
    if (serialized == null || serialized === lastSerialized.current) return;

    setStatus("saving");
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      try {
        const envelope: Envelope<T> = { v: value, t: Date.now() };
        window.localStorage.setItem(storageKey, JSON.stringify(envelope));
        lastSerialized.current = serialized;
        setSavedAt(envelope.t);
        setStatus("saved");
      } catch {
        setStatus("error");
      }
    }, debounceMs);

    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, [value, enabled, storageKey, debounceMs, isEmpty]);

  const clear = useCallback(() => {
    if (typeof window === "undefined") return;
    try {
      window.localStorage.removeItem(storageKey);
    } catch {
      /* noop */
    }
    lastSerialized.current = null;
    setInitial(null);
    setSavedAt(null);
    setStatus("idle");
  }, [storageKey]);

  const restore = useCallback(() => (initial ? initial.v : null), [initial]);

  return {
    draft: initial?.v ?? null,
    draftAt: initial?.t ?? null,
    hasDraft: initial !== null,
    clear,
    restore,
    status,
    savedAt,
  };
}

function safeStringify(v: unknown): string | null {
  try {
    return JSON.stringify(v);
  } catch {
    return null;
  }
}

/**
 * useConflictGuard — détecte un conflit d'édition concurrente.
 *
 * Compare `remoteUpdatedAt` (venant du serveur, refetché en Realtime via
 * `use-realtime-bus`) au `loadedAt` initial. Si le serveur est plus récent
 * ET que l'utilisateur a modifié localement, on remonte `hasConflict=true`
 * pour proposer un merge/refresh.
 */
export function useConflictGuard(params: {
  remoteUpdatedAt: string | null | undefined;
  loadedAt: number;
  isDirty: boolean;
}): { hasConflict: boolean } {
  const { remoteUpdatedAt, loadedAt, isDirty } = params;
  if (!remoteUpdatedAt || !isDirty) return { hasConflict: false };
  const remoteMs = new Date(remoteUpdatedAt).getTime();
  return { hasConflict: Number.isFinite(remoteMs) && remoteMs > loadedAt };
}
