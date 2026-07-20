import { createFileRoute, Outlet } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/produits")({
  component: ProduitsLayout,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function ProduitsLayout() {
  return <Outlet />;
}
