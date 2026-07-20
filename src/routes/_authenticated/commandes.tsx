import { createFileRoute, Outlet } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/commandes")({
  component: CommandesLayout,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function CommandesLayout() {
  return <Outlet />;
}
