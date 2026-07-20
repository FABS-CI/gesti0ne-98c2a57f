import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  assignRoleToUser,
  bulkSetRolePermissions,
  copyRolePermissions,
  createRole,
  deleteRole,
  duplicateRole,
  listAuditLog,
  listPermissions,
  listRolePermissions,
  listRoles,
  listUserProfiles,
  listUserRoleAssignments,
  revokeRoleFromUser,
  setRolePermission,
  updateRole,
  type RbacRole,
} from "@/lib/rbac-api";
import { friendlyError } from "@/lib/friendly-error";

// ── Rôles ──────────────────────────────────────────────────────────────────
export function useRolesQuery() {
  return useQuery({ queryKey: ["rbac", "roles"], queryFn: listRoles });
}

export function usePermissionsCatalogQuery() {
  return useQuery({
    queryKey: ["rbac", "permissions"],
    queryFn: listPermissions,
    // Le catalogue de permissions est quasi-statique : on évite les 160 k refetch
    // observés en prod. Il n'est invalidé que par les mutations de rôles.
    staleTime: 10 * 60 * 1000,
    gcTime: 30 * 60 * 1000,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
  });
}

export function useDeleteRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteRole(id),
    onSuccess: () => {
      toast.success("Rôle supprimé");
      qc.invalidateQueries({ queryKey: ["rbac", "roles"] });
    },
    onError: (e: Error) => toast.error(friendlyError(e)),
  });
}

export function useDuplicateRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      sourceRoleId,
      newCode,
      newLibelle,
    }: {
      sourceRoleId: string;
      newCode: string;
      newLibelle: string;
    }) => duplicateRole(sourceRoleId, newCode, newLibelle),
    onSuccess: () => {
      toast.success("Rôle dupliqué");
      qc.invalidateQueries({ queryKey: ["rbac", "roles"] });
      qc.invalidateQueries({ queryKey: ["rbac", "role-permissions"] });
    },
    onError: (e: Error) => toast.error(friendlyError(e)),
  });
}

export function useToggleRoleActive() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ roleId, actif }: { roleId: string; actif: boolean }) =>
      updateRole(roleId, { actif }),
    onSuccess: (_d, vars) => {
      toast.success(vars.actif ? "Rôle activé" : "Rôle désactivé");
      qc.invalidateQueries({ queryKey: ["rbac", "roles"] });
    },
    onError: (e: Error) => toast.error(friendlyError(e)),
  });
}

export function useSaveRole(
  isEdit: boolean,
  role: RbacRole | null | undefined,
  onSuccess: () => void,
) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (fields: {
      code: string;
      libelle: string;
      description: string | null;
      hierite_de: string | null;
    }) => {
      if (isEdit && role) {
        await updateRole(role.role_id, {
          libelle: fields.libelle,
          description: fields.description,
          hierite_de: fields.hierite_de,
        });
      } else {
        await createRole({
          code: fields.code.trim().toLowerCase().replace(/\s+/g, "_"),
          libelle: fields.libelle,
          description: fields.description,
          hierite_de: fields.hierite_de,
        });
      }
    },
    onSuccess: () => {
      toast.success(isEdit ? "Rôle mis à jour" : "Rôle créé");
      qc.invalidateQueries({ queryKey: ["rbac", "roles"] });
      onSuccess();
    },
    onError: (e: Error) => toast.error(friendlyError(e)),
  });
}

// ── Matrice permissions ────────────────────────────────────────────────────
export function useRolePermissionsQuery(roleId: string | null) {
  return useQuery({
    queryKey: ["rbac", "role-permissions", roleId],
    enabled: !!roleId,
    queryFn: () => listRolePermissions(roleId!),
    staleTime: Number.POSITIVE_INFINITY,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
  });
}

export function useTogglePermission(currentRoleId: string | null) {
  const qc = useQueryClient();
  const queryKey = ["rbac", "role-permissions", currentRoleId] as const;
  return useMutation({
    mutationKey: ["rbac", "toggle-permission", currentRoleId],
    scope: { id: `rbac-role-permissions-${currentRoleId ?? "none"}` },
    mutationFn: async ({ code, next }: { code: string; next: boolean }) => {
      if (!currentRoleId) return;
      await setRolePermission(currentRoleId, code, next);
    },
    // Optimistic : la case bascule immédiatement, on rollback en cas d'erreur.
    onMutate: async ({ code, next }) => {
      if (!currentRoleId) return { previous: undefined };
      await qc.cancelQueries({ queryKey });
      const previous = qc.getQueryData<Array<{ role_id: string; permission_code: string; accorde: boolean }>>(queryKey);
      qc.setQueryData(queryKey, (old: typeof previous) => {
        const list = old ?? [];
        const idx = list.findIndex((r) => r.permission_code === code);
        if (next) {
          if (idx >= 0) {
            const copy = list.slice();
            copy[idx] = { ...copy[idx], accorde: true };
            return copy;
          }
          return [...list, { role_id: currentRoleId, permission_code: code, accorde: true }];
        }
        return list.filter((r) => r.permission_code !== code);
      });
      return { previous };
    },
    onSuccess: () => {
      toast.success("✓ Permission enregistrée", { id: "rbac-perm-saved", duration: 1200 });
    },
    onError: (e: Error, _vars, ctx) => {
      if (ctx?.previous !== undefined) qc.setQueryData(queryKey, ctx.previous);
      toast.error(friendlyError(e, "Échec de l'enregistrement"));
    },
    // Force la resynchronisation avec la DB : évite qu'une case reste "cochée"
    // dans l'UI si la RPC a échoué silencieusement ou si une écriture partielle
    // a eu lieu. Invalide aussi le cache des permissions utilisateur pour que
    // les sessions ouvertes recalculent immédiatement les menus/gardes.
    onSettled: () => {
      qc.invalidateQueries({ queryKey });
      // Note : on n'invalide PAS ["rbac","permissions"] (catalogue statique) —
      // seulement les permissions par utilisateur, gérées par le realtime RBAC
      // et rafraîchies au focus onglet dans use-permissions.
    },
  });
}

export function useBulkSetPermissions(currentRoleId: string | null) {
  const qc = useQueryClient();
  const queryKey = ["rbac", "role-permissions", currentRoleId] as const;
  return useMutation({
    mutationKey: ["rbac", "bulk-permissions", currentRoleId],
    scope: { id: `rbac-role-permissions-${currentRoleId ?? "none"}` },
    mutationFn: async ({ codes, next }: { codes: string[]; next: boolean }) => {
      if (!currentRoleId) return;
      await bulkSetRolePermissions(currentRoleId, codes, next);
    },
    onMutate: async ({ codes, next }) => {
      if (!currentRoleId) return { previous: undefined };
      await qc.cancelQueries({ queryKey });
      const previous = qc.getQueryData<Array<{ role_id: string; permission_code: string; accorde: boolean }>>(queryKey);
      const codeSet = new Set(codes);
      qc.setQueryData(queryKey, (old: typeof previous) => {
        const list = old ?? [];
        if (next) {
          const map = new Map(list.map((r) => [r.permission_code, r]));
          for (const c of codes) map.set(c, { role_id: currentRoleId, permission_code: c, accorde: true });
          return Array.from(map.values());
        }
        return list.filter((r) => !codeSet.has(r.permission_code));
      });
      return { previous };
    },
    onSuccess: () => {
      toast.success("✓ Permissions mises à jour", { id: "rbac-perm-bulk", duration: 1500 });
    },
    onError: (e: Error, _vars, ctx) => {
      if (ctx?.previous !== undefined) qc.setQueryData(queryKey, ctx.previous);
      toast.error(friendlyError(e, "Échec de la mise à jour"));
    },
    onSettled: () => {
      qc.invalidateQueries({ queryKey });
      // Idem : ne pas invalider le catalogue de permissions à chaque toggle.
    },
  });
}

export function useCopyPermissions(currentRoleId: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (copyFrom: string) => {
      if (!currentRoleId || !copyFrom) return;
      await copyRolePermissions(copyFrom, currentRoleId);
    },
    onSuccess: () => {
      toast.success("Permissions copiées");
      qc.invalidateQueries({ queryKey: ["rbac", "role-permissions", currentRoleId] });
    },
    onError: (e: Error) => toast.error(friendlyError(e)),
  });
}

// ── Utilisateurs ───────────────────────────────────────────────────────────
export function useUserProfilesQuery() {
  return useQuery({ queryKey: ["rbac", "user-profiles"], queryFn: listUserProfiles });
}

export function useUserRoleAssignsQuery() {
  return useQuery({ queryKey: ["rbac", "user-role-assigns"], queryFn: listUserRoleAssignments });
}

export function useToggleUserRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      userId,
      roleId,
      next,
    }: {
      userId: string;
      roleId: string;
      next: boolean;
    }) => {
      if (next) await assignRoleToUser(userId, roleId);
      else await revokeRoleFromUser(userId, roleId);
    },
    onSuccess: () => {
      toast.success("Assignation mise à jour");
      qc.invalidateQueries({ queryKey: ["rbac", "user-role-assigns"] });
    },
    onError: (e: Error) => toast.error(friendlyError(e)),
  });
}

// ── Audit ──────────────────────────────────────────────────────────────────
export function useAuditLogQuery() {
  return useQuery({ queryKey: ["rbac", "audit"], queryFn: () => listAuditLog(300) });
}
