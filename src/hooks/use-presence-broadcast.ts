import { useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";
import { trackPresence, untrackPresence } from "@/lib/presence-channel";

/**
 * Publie l'état de présence de l'utilisateur courant sur le canal partagé
 * `app-presence` via le singleton `presence-channel`. Cela garantit qu'un
 * seul canal Realtime est ouvert, que ses handlers `.on('presence', …)`
 * sont enregistrés avant `subscribe()`, et que les observers
 * (`useOnlinePresence`) peuvent s'y greffer sans conflit.
 */
export function usePresenceBroadcast(user: {
  id: string;
  email: string | null | undefined;
}) {
  const lastActivityRef = useRef<number>(Date.now());

  useEffect(() => {
    if (!user?.id || !user.email) return;
    let cancelled = false;

    const connectedAt = new Date().toISOString();
    const userAgent =
      typeof navigator !== "undefined" ? navigator.userAgent : null;

    let profile: {
      nom_complet: string | null;
      prenom: string | null;
      fonction: string | null;
    } = { nom_complet: null, prenom: null, fonction: null };

    const publish = () => {
      if (cancelled) return;
      void trackPresence(user.id, {
        user_id: user.id,
        email: user.email!,
        nom_complet: profile.nom_complet,
        prenom: profile.prenom,
        fonction: profile.fonction,
        connected_at: connectedAt,
        last_activity: new Date(lastActivityRef.current).toISOString(),
        user_agent: userAgent,
        url: typeof window !== "undefined" ? window.location.pathname : null,
      });
    };

    // Récupère le profil puis publie une première fois.
    (async () => {
      const { data } = await supabase
        .from("profiles")
        .select("nom_complet, prenom, fonction")
        .eq("id", user.id)
        .maybeSingle();
      if (cancelled) return;
      if (data) profile = data;
      publish();
    })();

    const bump = () => {
      lastActivityRef.current = Date.now();
    };
    const events = ["mousedown", "keydown", "scroll", "touchstart", "click"];
    events.forEach((e) =>
      document.addEventListener(e, bump, { passive: true }),
    );

    const interval = window.setInterval(publish, 30_000);

    const onLeave = () => {
      void untrackPresence();
    };
    window.addEventListener("pagehide", onLeave);
    window.addEventListener("beforeunload", onLeave);

    return () => {
      cancelled = true;
      window.clearInterval(interval);
      events.forEach((e) => document.removeEventListener(e, bump));
      window.removeEventListener("pagehide", onLeave);
      window.removeEventListener("beforeunload", onLeave);
      onLeave();
    };
  }, [user?.id, user?.email]);
}
