import { createFileRoute } from "@tanstack/react-router";
import { ClientForm } from "@/components/clients/form/ClientForm";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/clients/$clientId/modifier")({
  component: ClientEditPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function ClientEditPage() {
  const { clientId } = Route.useParams();
  return <ClientForm clientId={clientId} />;
}
