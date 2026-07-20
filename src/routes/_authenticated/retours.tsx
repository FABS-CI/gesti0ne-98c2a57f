import { createFileRoute, Outlet } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/retours")({
  component: RetoursLayout,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function RetoursLayout() {
  return <Outlet />;
}
