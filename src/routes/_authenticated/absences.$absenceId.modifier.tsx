import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { absencesConfig } from "@/lib/rh-resources/absences.config";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/absences/$absenceId/modifier")({
  component: EditPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
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
