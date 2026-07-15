import { createFileRoute, redirect } from "@tanstack/react-router";

// Doublon supprimé — la gestion des tournées est centralisée dans le module /tournees.
export const Route = createFileRoute("/_authenticated/livraison-suivi/tournees")({
  beforeLoad: () => {
    throw redirect({ to: "/tournees" });
  },
});
