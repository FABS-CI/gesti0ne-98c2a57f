import { createFileRoute, redirect } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  beforeLoad: () => {
    // `/auth` redirige déjà une session active vers sa page d'arrivée.
    // Passer d'abord par le dashboard créait plusieurs documents SSR successifs
    // et pouvait hydrater la page de connexion avec l'état de la route précédente.
    throw redirect({ to: "/auth" });
  },
});
