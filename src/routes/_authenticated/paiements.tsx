import { createFileRoute, Outlet } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/paiements")({
  component: PaiementsLayout,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function PaiementsLayout() {
  return <Outlet />;
}
