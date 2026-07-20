import { createFileRoute, Outlet } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/transferts")({
  component: () => <Outlet />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
