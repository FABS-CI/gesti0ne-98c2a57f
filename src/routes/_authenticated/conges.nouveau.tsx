import { createFileRoute } from "@tanstack/react-router";
import { CongeForm } from "@/components/conges/CongeForm";

export const Route = createFileRoute("/_authenticated/conges/nouveau")({
  component: () => <CongeForm mode="create" />,
});
