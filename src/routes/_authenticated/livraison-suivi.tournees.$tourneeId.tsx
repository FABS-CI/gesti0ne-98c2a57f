import { createFileRoute, redirect } from "@tanstack/react-router";

// Doublon supprimé — le détail d'une tournée vit dans le module /tournees.
export const Route = createFileRoute("/_authenticated/livraison-suivi/tournees/$tourneeId")({
  beforeLoad: ({ params }) => {
    const { tourneeId } = params as { tourneeId: string };
    throw redirect({ to: "/tournees/$tourneeId", params: { tourneeId } });
  },
});
