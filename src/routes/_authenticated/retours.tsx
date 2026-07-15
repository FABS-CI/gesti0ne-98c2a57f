import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/retours")({
  component: RetoursLayout,
});

function RetoursLayout() {
  return <Outlet />;
}
