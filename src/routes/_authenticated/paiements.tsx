import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/paiements")({
  component: PaiementsLayout,
});

function PaiementsLayout() {
  return <Outlet />;
}
