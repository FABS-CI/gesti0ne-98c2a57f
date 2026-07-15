import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { evaluationsConfig } from "@/lib/rh-resources/evaluations.config";

export const Route = createFileRoute("/_authenticated/evaluations/$evaluationId/modifier")({
  component: EditPage,
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
