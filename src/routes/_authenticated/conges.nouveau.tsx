import { createFileRoute } from "@tanstack/react-router";
import { CongeForm } from "@/components/conges/CongeForm";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/conges/nouveau")({
  component: () => <CongeForm mode="create" />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
