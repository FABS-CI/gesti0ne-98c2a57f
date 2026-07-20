import { createFileRoute } from "@tanstack/react-router";
import { ResourceManager } from "@/components/crud/ResourceManager";
import { absencesConfig } from "@/lib/rh-resources/absences.config";

import { authRouteHead } from "@/lib/route-head";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";
export const Route = createFileRoute("/_authenticated/absences/")({
  head: () => authRouteHead("Absences"),
  component: () => <ResourceManager config={absencesConfig} />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
