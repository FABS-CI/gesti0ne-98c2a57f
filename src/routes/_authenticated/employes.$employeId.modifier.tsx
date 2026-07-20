import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { getEmploye } from "@/lib/rh-api";
import { EmployeForm } from "@/components/rh/EmployeForm";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/employes/$employeId/modifier")({
  component: EditEmployePage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function EditEmployePage() {
  const { employeId } = Route.useParams();
  const { data, isLoading, error } = useQuery({
    queryKey: ["employe", employeId],
    queryFn: () => getEmploye(employeId),
  });
  if (isLoading) return <div className="p-8 text-muted-foreground">Chargement…</div>;
  if (error || !data) return <div className="p-8 text-destructive">Employé introuvable.</div>;
  return <EmployeForm employe={data} />;
}
