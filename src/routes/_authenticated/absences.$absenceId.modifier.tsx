import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { absencesConfig } from "@/lib/rh-resources/absences.config";

export const Route = createFileRoute("/_authenticated/absences/$absenceId/modifier")({
  component: EditPage,
});

function EditPage() {
  const { absenceId } = Route.useParams();
  return (
    <ResourceFormPage
      config={absencesConfig}
      mode="edit"
      recordId={absenceId}
      listPath="/absences"
    />
  );
}
