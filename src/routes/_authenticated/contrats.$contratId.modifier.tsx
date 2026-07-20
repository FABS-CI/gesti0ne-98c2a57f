import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { contratsConfig } from "@/lib/rh-resources/contrats.config";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/contrats/$contratId/modifier")({
  component: EditPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function EditPage() {
  const { contratId } = Route.useParams();
  return (
    <ResourceFormPage
      config={contratsConfig}
      mode="edit"
      recordId={contratId}
      listPath="/contrats"
    />
  );
}
