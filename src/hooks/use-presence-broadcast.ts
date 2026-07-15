import { useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";

/**
 * Publie l'état de présence de l'utilisateur courant sur le canal
 * partagé `app-presence`. Détecte automatiquement les fermetures brutales
 * de navigateur / pertes réseau via la déconnexion websocket côté serveur.
 *
 * Le canal utilise Supabase Realtime Presence : chaque client "track()" ses
 * infos, tous les autres clients abonnés reçoivent les changements en direct.
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

    // Récupère nom/prénom/fonction depuis profiles (best-effort).
    let profile: {
      nom_complet: string | null;
      prenom: string | null;
      fonction: string | null;
    } = { nom_complet: null, prenom: null, fonction: null };

    const channel = supabase.channel("app-presence", {
      config: { presence: { key: user.id } },
    });

    const publish = () => {
      if (cancelled) return;
      void channel.track({
        user_id: user.id,
        email: user.email,
        nom_complet: profile.nom_complet,
        prenom: profile.prenom,
        fonction: profile.fonction,
        connected_at: connectedAt,
        last_activity: new Date(lastActivityRef.current).toISOString(),
        user_agent: userAgent,
        url: typeof window !== "undefined" ? window.location.pathname : null,
      });
    };

    channel.subscribe(async (status) => {
      if (status !== "SUBSCRIBED" || cancelled) return;
      const { data } = await supabase
        .from("profiles")
        .select("nom_complet, prenom, fonction")
        .eq("id", user.id)
        .maybeSingle();
      if (data) profile = data;
      publish();
    });

    // Marque l'activité utilisateur
    const bump = () => {
      lastActivityRef.current = Date.now();
    };
    const events = ["mousedown", "keydown", "scroll", "touchstart", "click"];
    events.forEach((e) =>
      document.addEventListener(e, bump, { passive: true }),
    );

    // Republie l'état toutes les 30 s pour rafraîchir last_activity
    const interval = window.setInterval(publish, 30_000);

    // Nettoie la présence lors de la fermeture / navigation
    const onLeave = () => {
      try {
        void channel.untrack();
      } catch {
        /* noop */
      }
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
      supabase.removeChannel(channel);
    };
  }, [user?.id, user?.email]);
}
