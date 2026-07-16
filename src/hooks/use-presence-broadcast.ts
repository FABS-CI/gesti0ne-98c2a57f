import { useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";
import { trackPresence, untrackPresence } from "@/lib/presence-channel";
import { parseUserAgent } from "@/lib/ua-parse";

type Geo = {
  ip: string | null;
  city: string | null;
  region: string | null;
  country: string | null;
  country_code: string | null;
  isp: string | null;
};

async function fetchOwnGeo(): Promise<Geo> {
  const empty: Geo = {
    ip: null,
    city: null,
    region: null,
    country: null,
    country_code: null,
    isp: null,
  };
  try {
    const r = await fetch("https://ipwho.is/");
    if (!r.ok) return empty;
    const j = await r.json();
    if (!j || j.success === false) return empty;
    return {
      ip: j.ip ?? null,
      city: j.city ?? null,
      region: j.region ?? null,
      country: j.country ?? null,
      country_code: j.country_code ?? null,
      isp: j.connection?.isp ?? null,
    };
  } catch {
    return empty;
  }
}

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
    const parsed = parseUserAgent(userAgent);

    let profile: {
      nom_complet: string | null;
      prenom: string | null;
      fonction: string | null;
    } = { nom_complet: null, prenom: null, fonction: null };

    let geo: Geo = {
      ip: null,
      city: null,
      region: null,
      country: null,
      country_code: null,
      isp: null,
    };

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
        ip: geo.ip,
        city: geo.city,
        region: geo.region,
        country: geo.country,
        country_code: geo.country_code,
        isp: geo.isp,
        device: parsed.device === "Inconnu" ? null : parsed.device,
        browser: parsed.browser === "—" ? null : parsed.browser,
        os: parsed.os === "—" ? null : parsed.os,
      });
    };

    // Récupère le profil + la géoloc IP puis publie.
    (async () => {
      const [{ data }, g] = await Promise.all([
        supabase
          .from("profiles")
          .select("nom_complet, prenom, fonction")
          .eq("id", user.id)
          .maybeSingle(),
        fetchOwnGeo(),
      ]);
      if (cancelled) return;
      if (data) profile = data;
      geo = g;
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
