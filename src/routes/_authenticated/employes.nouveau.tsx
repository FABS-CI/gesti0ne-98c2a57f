import { createFileRoute } from "@tanstack/react-router";
import { EmployeForm } from "@/components/rh/EmployeForm";

export const Route = createFileRoute("/_authenticated/employes/nouveau")({
  component: () => <EmployeForm />,
});
