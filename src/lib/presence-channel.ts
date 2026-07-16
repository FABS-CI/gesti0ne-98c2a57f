import { supabase } from "@/integrations/supabase/client";
import type { RealtimeChannel } from "@supabase/supabase-js";
import type { OnlinePresence } from "@/hooks/use-online-presence";

/**
 * Singleton du canal Realtime `app-presence`.
 *
 * Contexte : `supabase.channel(topic)` déduplique par topic. Si un premier
 * consommateur (broadcast) fait `.subscribe()`, un second consommateur qui
 * essaie d'ajouter `.on('presence', …)` obtient l'instance déjà joined et
 * `realtime-js` lève « cannot add presence callbacks after subscribe() ».
 *
 * On centralise donc :
 *  1. l'enregistrement des `.on()` (une seule fois, avant subscribe),
 *  2. la subscription différée jusqu'à ce qu'on ait au moins un listener /
 *     publisher (évite d'ouvrir un WS inutile),
 *  3. les listeners applicatifs qui reçoivent le presenceState courant.
 */

type Listener = (state: OnlinePresence[]) => void;

let channel: RealtimeChannel | null = null;
let subscribed = false;
let presenceKey: string | null = null;
const listeners = new Set<Listener>();

function computeState(ch: RealtimeChannel): OnlinePresence[] {
  const raw = ch.presenceState<OnlinePresence>();
  const list: OnlinePresence[] = [];
  Object.values(raw).forEach((entries) => {
    const latest = entries.reduce((a, b) =>
      new Date(a.last_activity) > new Date(b.last_activity) ? a : b,
    );
    if (latest) list.push(latest);
  });
  return list;
}

function notify() {
  if (!channel) return;
  const state = computeState(channel);
  listeners.forEach((l) => l(state));
}

function ensureChannel(key?: string): RealtimeChannel {
  // Si un publisher fournit une clé de présence différente, on recycle le
  // canal existant (impossible de changer la clé après création).
  if (channel && key && presenceKey !== key) {
    try {
      void supabase.removeChannel(channel);
    } catch {
      /* noop */
    }
    channel = null;
    subscribed = false;
    presenceKey = null;
  }
  let ch = channel;
  if (!ch) {
    presenceKey = key ?? null;
    ch = supabase.channel(
      "app-presence",
      key ? { config: { presence: { key } } } : undefined,
    );
    ch.on("presence", { event: "sync" }, notify)
      .on("presence", { event: "join" }, notify)
      .on("presence", { event: "leave" }, notify);
    channel = ch;
  }
  if (!subscribed) {
    subscribed = true;
    ch.subscribe();
  }
  return ch;
}

/** Abonne un listener aux changements de présence. Retourne un unsubscribe. */
export function subscribePresence(listener: Listener): () => void {
  const ch = ensureChannel();
  listeners.add(listener);
  // Push initial state
  listener(computeState(ch));
  return () => {
    listeners.delete(listener);
  };
}

/** Publie (ou met à jour) la présence de l'utilisateur courant. */
export async function trackPresence(
  key: string,
  payload: Omit<OnlinePresence, never>,
): Promise<void> {
  const ch = ensureChannel(key);
  try {
    await ch.track(payload);
  } catch {
    /* noop */
  }
}

/** Retire la présence de l'utilisateur courant sans détruire le canal. */
export async function untrackPresence(): Promise<void> {
  if (!channel) return;
  try {
    await channel.untrack();
  } catch {
    /* noop */
  }
}
