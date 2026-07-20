import { createFileRoute, Outlet } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/factures")({
  component: FacturesLayout,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function FacturesLayout() {
  return <Outlet />;
}
