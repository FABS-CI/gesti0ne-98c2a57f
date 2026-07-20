import { createFileRoute, redirect } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/fne-settings")({
  beforeLoad: () => {
    throw redirect({ to: "/fne", search: { tab: "settings" } });
  },
});
