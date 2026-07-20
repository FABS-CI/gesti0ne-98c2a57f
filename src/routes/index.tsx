import { createFileRoute } from "@tanstack/react-router";
import { useEffect } from "react";

export const Route = createFileRoute("/")({
  component: IndexRedirect,
});

function IndexRedirect() {
  useEffect(() => {
    // La preview ouvre toujours `/`. Une redirection HTTP à cet endroit pouvait
    // mélanger l'état SSR de `/` avec le document final de `/auth` pendant
    // l'hydratation. Un nouveau document explicite élimine cette course.
    window.location.replace("/auth");
  }, []);

  return null;
}
