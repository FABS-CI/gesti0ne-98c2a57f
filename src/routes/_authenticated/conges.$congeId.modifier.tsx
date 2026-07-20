import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Skeleton } from "@/components/ui/skeleton";
import { getConge } from "@/lib/rh-api";
import { CongeForm } from "@/components/conges/CongeForm";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/conges/$congeId/modifier")({
  component: EditCongePage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function EditCongePage() {
  const { congeId } = Route.useParams();
  const { data, isLoading, error } = useQuery({
    queryKey: ["conge", congeId],
    queryFn: () => getConge(congeId),
  });

  if (isLoading) return <Skeleton className="h-96 w-full" />;
  if (error || !data)
    return <div className="p-6 text-sm text-destructive">Demande introuvable</div>;

  return (
    <CongeForm
      mode="edit"
      id={data.conge_id}
      initial={{
        employe_id: data.employe_id,
        type: data.type,
        date_debut: data.date_debut,
        date_fin: data.date_fin,
        motif: data.motif ?? "",
        statut: data.statut,
      }}
    />
  );
}
