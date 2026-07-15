import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/produits")({
  component: ProduitsLayout,
});

function ProduitsLayout() {
  return <Outlet />;
}
