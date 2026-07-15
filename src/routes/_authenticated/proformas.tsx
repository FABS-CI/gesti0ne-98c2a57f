import { createFileRoute, Outlet } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/proformas")({
  component: ProformasLayout,
});

function ProformasLayout() {
  return <Outlet />;
}
