import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/use-auth";
import { signOutAndRedirect } from "@/lib/auth/logout";

/**
 * Bloque l'accès à l'application si le profil de l'utilisateur connecté
 * a été désactivé (`profiles.actif = false`). Déconnecte automatiquement.
 */
export function ActifGate({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  const [kickingOut, setKickingOut] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ["profile-actif", user?.id],
    enabled: !!user?.id,
    staleTime: 10 * 60_000, // 10 min : profils actif change rarement
    gcTime: 30 * 60_000,
    refetchOnWindowFocus: false,
    refetchOnMount: false,
    queryFn: async () => {
      const { data } = await supabase
        .from("profiles")
        .select("actif")
        .eq("id", user!.id)
        .maybeSingle();
      return data;
    },
  });

  useEffect(() => {
    if (!user?.id) return;
    if (isLoading) return;
    if (data && data.actif === false && !kickingOut) {
      setKickingOut(true);
      void signOutAndRedirect("account_disabled");
    }
  }, [data, isLoading, user?.id, kickingOut]);

  if (kickingOut || (data && data.actif === false)) {
    return (
      <div className="flex h-64 items-center justify-center text-sm text-muted-foreground">
        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
        Déconnexion en cours…
      </div>
    );
  }

  return <>{children}</>;
}