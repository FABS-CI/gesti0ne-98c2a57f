import { createFileRoute } from "@tanstack/react-router";
import { ResourceManager } from "@/components/crud/ResourceManager";
import { evaluationsConfig } from "@/lib/rh-resources/evaluations.config";

import { authRouteHead } from "@/lib/route-head";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";
export const Route = createFileRoute("/_authenticated/evaluations/")({
  head: () => authRouteHead("Évaluations"),
  component: () => <ResourceManager config={evaluationsConfig} />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
