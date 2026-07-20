import { createFileRoute } from "@tanstack/react-router";
import { ResourceManager } from "@/components/crud/ResourceManager";
import { contratsConfig } from "@/lib/rh-resources/contrats.config";

import { authRouteHead } from "@/lib/route-head";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";
export const Route = createFileRoute("/_authenticated/contrats/")({
  head: () => authRouteHead("Contrats"),
  component: () => <ResourceManager config={contratsConfig} />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
