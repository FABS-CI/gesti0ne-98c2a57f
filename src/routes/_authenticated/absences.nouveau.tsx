import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { absencesConfig } from "@/lib/rh-resources/absences.config";

export const Route = createFileRoute("/_authenticated/absences/nouveau")({
  component: () => <ResourceFormPage config={absencesConfig} mode="create" listPath="/absences" />,
});
