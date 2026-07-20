import { createFileRoute, Outlet } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/proformas")({
  component: ProformasLayout,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function ProformasLayout() {
  return <Outlet />;
}
