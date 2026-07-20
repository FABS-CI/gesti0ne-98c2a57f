import { createFileRoute, redirect } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/fne-logs")({
  beforeLoad: () => {
    throw redirect({ to: "/fne", search: { tab: "logs" } });
  },
});
