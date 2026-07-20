import { createFileRoute } from "@tanstack/react-router";
import { EmployeForm } from "@/components/rh/EmployeForm";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/employes/nouveau")({
  component: () => <EmployeForm />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
