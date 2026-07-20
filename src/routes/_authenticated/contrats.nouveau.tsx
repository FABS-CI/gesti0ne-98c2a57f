import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { contratsConfig } from "@/lib/rh-resources/contrats.config";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/contrats/nouveau")({
  component: () => <ResourceFormPage config={contratsConfig} mode="create" listPath="/contrats" />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
