import { createFileRoute, redirect } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/fne-settings")({
  beforeLoad: () => {
    throw redirect({ to: "/fne", search: { tab: "settings" } });
  },
});
