import { createFileRoute } from "@tanstack/react-router";
import { ResourceManager } from "@/components/crud/ResourceManager";
import { absencesConfig } from "@/lib/rh-resources/absences.config";

import { authRouteHead } from "@/lib/route-head";
export const Route = createFileRoute("/_authenticated/absences/")({
  head: () => authRouteHead("Absences"),
  component: () => <ResourceManager config={absencesConfig} />,
});
