import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { FournisseurFormPage } from "@/components/fournisseurs/FournisseurFormPage";
import { getFournisseur } from "@/lib/fournisseurs-api";
import { authRouteHead } from "@/lib/route-head";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/fournisseurs/$fournisseurId/modifier")({
  head: () => authRouteHead("Modifier le fournisseur"),
  component: ModifierFournisseurPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function ModifierFournisseurPage() {
  const { fournisseurId } = Route.useParams();
  const { data, isLoading } = useQuery({
    queryKey: ["fournisseur", fournisseurId],
    queryFn: () => getFournisseur(fournisseurId),
  });

  if (isLoading) {
    return <div className="p-6 text-muted-foreground">Chargement…</div>;
  }
  if (!data) {
    return <div className="p-6 text-muted-foreground">Fournisseur introuvable.</div>;
  }
  return <FournisseurFormPage existing={data} />;
}
