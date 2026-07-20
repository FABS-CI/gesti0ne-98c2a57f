import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { absencesConfig } from "@/lib/rh-resources/absences.config";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/absences/nouveau")({
  component: () => <ResourceFormPage config={absencesConfig} mode="create" listPath="/absences" />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
