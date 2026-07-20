import { useEffect, useState } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";

export function useAuth() {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let unsubscribe = () => {};
    let active = true;

    try {
      const { data: sub } = supabase.auth.onAuthStateChange((_event, nextSession) => {
        if (!active) return;
        setSession(nextSession);
        setUser(nextSession?.user ?? null);
      });
      unsubscribe = () => sub.subscription.unsubscribe();
    } catch (error) {
      console.warn("[auth] Écoute de session indisponible", error);
    }

    void supabase.auth
      .getSession()
      .then(({ data }) => {
        if (!active) return;
        setSession(data.session);
        setUser(data.session?.user ?? null);
      })
      .catch((error) => {
        console.warn("[auth] Lecture de session indisponible", error);
        if (!active) return;
        setSession(null);
        setUser(null);
      })
      .finally(() => {
        if (active) setIsLoading(false);
      });

    return () => {
      active = false;
      unsubscribe();
    };
  }, []);

  return { session, user, isLoading };
}
