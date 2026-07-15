// @ts-nocheck — schema temporarily reduced after reset.
import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

export type OnlinePresence = {
  user_id: string;
  email: string;
  nom_complet: string | null;
  prenom: string | null;
  fonction: string | null;
  connected_at: string;
  last_activity: string;
  user_agent: string | null;
  url: string | null;
};

/**
 * Abonnement en lecture seule au canal `app-presence`.
 * Retourne un tableau des utilisateurs actuellement connectés (websocket
 * ouvert). La détection est instantanée : dès qu'un client se déconnecte
 * (fermeture navigateur, perte réseau, expiration session), il disparaît.
 */
export function useOnlinePresence() {
  const [presences, setPresences] = useState<OnlinePresence[]>([]);

  useEffect(() => {
    const channel = supabase.channel("app-presence");

    const refresh = () => {
      const state = channel.presenceState<OnlinePresence>();
      const list: OnlinePresence[] = [];
      Object.values(state).forEach((entries) => {
        // On garde l'entrée la plus récente par user_id
        const latest = entries.reduce((a, b) =>
          new Date(a.last_activity) > new Date(b.last_activity) ? a : b,
        );
        if (latest) list.push(latest);
      });
      setPresences(list);
    };

    channel
      .on("presence", { event: "sync" }, refresh)
      .on("presence", { event: "join" }, refresh)
      .on("presence", { event: "leave" }, refresh)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  return presences;
}