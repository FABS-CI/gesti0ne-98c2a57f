import { createFileRoute, redirect } from "@tanstack/react-router";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

// Route statique prioritaire sur /produits/$produitId — redirige vers la page
// dédiée aux alertes de stock pour éviter la collision avec le détail produit.
export const Route = createFileRoute("/_authenticated/produits/alertes")({
  beforeLoad: () => {
    throw redirect({ to: "/alertes-stock" });
  },
});
