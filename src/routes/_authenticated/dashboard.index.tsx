import { createFileRoute, redirect } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/dashboard/")({
  beforeLoad: ({ context }) => {
    // Si l'utilisateur n'est pas authentifié, le middleware requireSupabaseAuth 
    // ou le parent _authenticated s'en charge. 
    // Ici on peut ajouter une vérification de rôle si nécessaire.
  },
  loader: () => {
    // Redirection systématique vers l'accueil (qui gère l'état de chargement et le split auth/dashboard)
    // Cela évite d'exposer des bribes de dashboard avant que le cache RBAC soit chaud.
    throw redirect({ to: "/" });
  },
});
