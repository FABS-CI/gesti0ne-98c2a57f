import { useQuery } from "@tanstack/react-query";

import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/use-auth";

/**
 * Restrictions d'accès individuelles, stockées en base (`profiles.route_restrictions`).
 *
 * Remplace l'ancienne liste codée en dur par email dans `src/lib/permissions.ts`.
 * Un Super Administrateur peut ajuster la liste sans redéploiement.
 */
export function useRouteRestrictions() {
  const { user, isLoading: authLoading } = useAuth();
  const userId = user?.id ?? null;

  const query = useQuery({
    queryKey: ["profile", "route-restrictions", userId],
    enabled: !!userId,
    staleTime: 10 * 60_000,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("profiles")
        .select("route_restrictions")
        .eq("id", userId!)
        .maybeSingle();
      if (error) throw error;
      return (data?.route_restrictions ?? []) as string[];
    },
  });

  const restrictions = query.data ?? [];

  const isRestricted = (pathname: string) =>
    restrictions.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));

  return { restrictions, isRestricted, isLoading: authLoading || query.isLoading };
}
