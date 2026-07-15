import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/commandes")({
  component: CommandesLayout,
});

function CommandesLayout() {
  return <Outlet />;
}
