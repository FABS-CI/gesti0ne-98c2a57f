import { createFileRoute, redirect } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/fne-logs")({
  beforeLoad: () => {
    throw redirect({ to: "/fne", search: { tab: "logs" } });
  },
});
