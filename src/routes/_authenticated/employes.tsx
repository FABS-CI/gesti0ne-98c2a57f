import { createFileRoute, Outlet } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/employes")({
  component: () => <Outlet />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
