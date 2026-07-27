import { createFileRoute } from "@tanstack/react-router";
import { FournisseurFormPage } from "@/components/fournisseurs/FournisseurFormPage";
import { authRouteHead } from "@/lib/route-head";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/fournisseurs/nouveau")({
  head: () => authRouteHead("Nouveau fournisseur"),
  component: () => <FournisseurFormPage />,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
