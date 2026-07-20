import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { evaluationsConfig } from "@/lib/rh-resources/evaluations.config";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/evaluations/nouveau")({
  component: () => (
    <ResourceFormPage config={evaluationsConfig} mode="create" listPath="/evaluations" />
  ),
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
