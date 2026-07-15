import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";
import { useMemo } from "react";
import { UserForm } from "@/components/roles-permissions/UserForm";
import {
  useUserProfilesQuery,
  useUserRoleAssignsQuery,
} from "@/hooks/use-roles-permissions";

export const Route = createFileRoute("/_authenticated/utilisateurs/$userId/modifier")({
  component: EditUserPage,
});

function EditUserPage() {
  const { userId } = Route.useParams();
  const navigate = useNavigate();
  const usersQ = useUserProfilesQuery();
  const assignsQ = useUserRoleAssignsQuery();

  const editing = useMemo(() => {
    const u = (usersQ.data ?? []).find((x) => x.id === userId);
    if (!u) return null;
    const role_ids = (assignsQ.data ?? [])
      .filter((a) => a.user_id === userId)
      .map((a) => a.role_id);
    return {
      id: u.id,
      email: u.email,
      nom_complet: u.nom_complet,
      prenom: u.prenom ?? null,
      telephone: u.telephone ?? null,
      fonction: u.fonction ?? null,
      departement: u.departement ?? null,
      avatar_url: u.avatar_url ?? null,
      actif: u.actif,
      role_ids,
    };
  }, [usersQ.data, assignsQ.data, userId]);

  if (usersQ.isLoading || assignsQ.isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }
  if (!editing) {
    navigate({ to: "/utilisateurs" });
    return null;
  }
  return <UserForm editing={editing} />;
}