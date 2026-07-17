import { useQuery } from "@tanstack/react-query";
import { getClient, getClientRelations } from "@/lib/clients-api";

export function useClientDetail(clientId: string) {
  const { data: client, isLoading } = useQuery({
    queryKey: ["client", clientId],
    queryFn: () => getClient(clientId),
    staleTime: 0,
    refetchOnMount: "always",
  });

  const { data: rel } = useQuery({
    queryKey: ["client-relations", clientId, client?.nom],
    queryFn: () => getClientRelations(clientId, client!.nom),
    enabled: !!client,
    staleTime: 0,
    refetchOnMount: "always",
  });

  return { client, rel, isLoading };
}
