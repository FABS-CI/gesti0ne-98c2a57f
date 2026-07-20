import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { evaluationsConfig } from "@/lib/rh-resources/evaluations.config";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/evaluations/$evaluationId/modifier")({
  component: EditPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function EditPage() {
  const { evaluationId } = Route.useParams();
  return (
    <ResourceFormPage
      config={evaluationsConfig}
      mode="edit"
      recordId={evaluationId}
      listPath="/evaluations"
    />
  );
}
