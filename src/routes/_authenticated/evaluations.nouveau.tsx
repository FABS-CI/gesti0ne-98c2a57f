import { createFileRoute } from "@tanstack/react-router";
import { ResourceFormPage } from "@/components/crud/ResourceFormPage";
import { evaluationsConfig } from "@/lib/rh-resources/evaluations.config";

export const Route = createFileRoute("/_authenticated/evaluations/nouveau")({
  component: () => (
    <ResourceFormPage config={evaluationsConfig} mode="create" listPath="/evaluations" />
  ),
});
