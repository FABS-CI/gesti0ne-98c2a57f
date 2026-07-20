import { createFileRoute, Outlet } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/clients")({
  component: ClientsLayout,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function ClientsLayout() {
  return <Outlet />;
}
