import { useCallback, useEffect, useRef, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

/**
 * useServerDraft — sauvegarde automatique d'un brouillon **côté serveur**
 * (table `document_drafts`), avec reprise de saisie et anti-doublon.
 *
 * Règles :
 * - Un seul brouillon actif par utilisateur + type de document : chaque
 *   sauvegarde fait un UPSERT sur (user_id, doc_type, draft_id).
 * - Au montage, si un brouillon `draft` existe, il est proposé à l'utilisateur
 *   (« reprendre » ou « recommencer »).
 * - À la validation finale, appeler `markConverted()` : le brouillon est marqué
 *   `converted` et ne sera plus proposé.
 * - Ne PAS utiliser pour un flux purement transactionnel sans formulaire long.
 */

export type ServerDraftOptions<T> = {
  /** Identifiant du formulaire, ex. "bon_reception", "commande", "paiement". */
  docType: string;
  /** Valeur courante du formulaire. */
  value: T;
  /** Entité liée éventuelle (édition d'un document existant). */
  entityId?: string | null;
  /** Débounce en ms (défaut 10 s). */
  debounceMs?: number;
  /** Désactive l'autosave (pendant submit, ou en mode édition). */
  enabled?: boolean;
  /** Filtre les valeurs vides pour ne pas créer de brouillon inutile. */
  isEmpty?: (v: T) => boolean;
};

export type ServerDraftState<T> = {
  /** Brouillon trouvé au montage (non encore repris ni écarté). */
  pendingDraft: { payload: T; updatedAt: string } | null;
  /** Reprend le brouillon trouvé (retourne le payload). */
  restore: () => T | null;
  /** Écarte et supprime le brouillon trouvé. */
  discard: () => Promise<void>;
  /** Marque le brouillon comme converti après validation du document. */
  markConverted: () => Promise<void>;
  status: "idle" | "saving" | "saved" | "error";
  savedAt: number | null;
};

type DraftRow = {
  draft_id: string;
  payload: unknown;
  updated_at: string;
};

function newDraftId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return `draft-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

// La table est générique : on passe par un client non typé pour éviter de
// dépendre de la régénération des types.
const drafts = () => (supabase as unknown as { from: (t: string) => any }).from("document_drafts");

export function useServerDraft<T>({
  docType,
  value,
  entityId = null,
  debounceMs = 10000,
  enabled = true,
  isEmpty,
}: ServerDraftOptions<T>): ServerDraftState<T> {
  const [pendingDraft, setPendingDraft] = useState<{ payload: T; updatedAt: string } | null>(null);
  const [status, setStatus] = useState<ServerDraftState<T>["status"]>("idle");
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const draftIdRef = useRef<string>(newDraftId());
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastSerialized = useRef<string | null>(null);
  const convertedRef = useRef(false);

  // Recherche d'un brouillon existant au montage
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await drafts()
        .select("draft_id, payload, updated_at")
        .eq("doc_type", docType)
        .eq("status", "draft")
        .order("updated_at", { ascending: false })
        .limit(1);
      const row = (data as DraftRow[] | null)?.[0];
      if (cancelled || !row) return;
      draftIdRef.current = row.draft_id;
      setPendingDraft({ payload: row.payload as T, updatedAt: row.updated_at });
    })();
    return () => {
      cancelled = true;
    };
  }, [docType]);

  // Autosave debounced
  useEffect(() => {
    if (!enabled || convertedRef.current) return;
    if (isEmpty?.(value)) return;
    let serialized: string;
    try {
      serialized = JSON.stringify(value);
    } catch {
      return;
    }
    if (serialized === lastSerialized.current) return;

    setStatus("saving");
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(async () => {
      const { data: auth } = await supabase.auth.getUser();
      const userId = auth.user?.id;
      if (!userId) return;
      const { error } = await drafts().upsert(
        {
          user_id: userId,
          doc_type: docType,
          draft_id: draftIdRef.current,
          entity_id: entityId,
          payload: value as unknown,
          status: "draft",
        },
        { onConflict: "user_id,doc_type,draft_id" },
      );
      if (error) {
        setStatus("error");
        return;
      }
      lastSerialized.current = serialized;
      setSavedAt(Date.now());
      setStatus("saved");
    }, debounceMs);

    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, [value, enabled, docType, entityId, debounceMs, isEmpty]);

  const restore = useCallback(() => {
    const payload = pendingDraft?.payload ?? null;
    setPendingDraft(null);
    return payload;
  }, [pendingDraft]);

  const discard = useCallback(async () => {
    setPendingDraft(null);
    await drafts().delete().eq("doc_type", docType).eq("status", "draft");
    draftIdRef.current = newDraftId();
    lastSerialized.current = null;
  }, [docType]);

  const markConverted = useCallback(async () => {
    convertedRef.current = true;
    if (timer.current) clearTimeout(timer.current);
    await drafts()
      .update({ status: "converted" })
      .eq("doc_type", docType)
      .eq("draft_id", draftIdRef.current);
    setPendingDraft(null);
    setStatus("idle");
  }, [docType]);

  return { pendingDraft, restore, discard, markConverted, status, savedAt };
}
