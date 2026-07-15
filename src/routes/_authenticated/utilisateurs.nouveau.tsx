import { createFileRoute } from "@tanstack/react-router";
import { UserForm } from "@/components/roles-permissions/UserForm";

export const Route = createFileRoute("/_authenticated/utilisateurs/nouveau")({
  component: () => <UserForm />,
});