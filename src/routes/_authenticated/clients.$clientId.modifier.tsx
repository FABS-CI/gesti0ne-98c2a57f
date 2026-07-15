import { createFileRoute } from "@tanstack/react-router";
import { ClientForm } from "@/components/clients/form/ClientForm";

export const Route = createFileRoute("/_authenticated/clients/$clientId/modifier")({
  component: ClientEditPage,
});

function ClientEditPage() {
  const { clientId } = Route.useParams();
  return <ClientForm clientId={clientId} />;
}
