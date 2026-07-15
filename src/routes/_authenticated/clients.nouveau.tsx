import { createFileRoute } from "@tanstack/react-router";
import { ClientForm } from "@/components/clients/form/ClientForm";

export const Route = createFileRoute("/_authenticated/clients/nouveau")({
  component: () => <ClientForm />,
});