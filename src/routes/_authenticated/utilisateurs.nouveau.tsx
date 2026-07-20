import { createFileRoute } from "@tanstack/react-router";
import { UserForm } from "@/components/roles-permissions/UserForm";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/utilisateurs/nouveau")({
  component: () => <UserForm />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});