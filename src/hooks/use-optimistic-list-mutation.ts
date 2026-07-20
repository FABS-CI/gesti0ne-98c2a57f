import { useCallback } from "react";
import {
  useMutation,
  useQueryClient,
  type QueryKey,
  type UseMutationOptions,
} from "@tanstack/react-query";
import { toast } from "sonner";

/**
 * Helper d'optimistic update pour listes React Query.
 *
 * Objectif : ressenti < 300 ms sur create/update/delete. L'UI met à jour
 * immédiatement le cache, envoie la requête serveur, et rollback en cas
 * d'erreur (le Realtime bus resynchronisera de toute façon).
 *
 * Exemple :
 *   const del = useOptimisticListMutation<Notification, string>({
 *     queryKey: ["notifications"],
 *     mutationFn: (id) => supabase.from("notifications").delete().eq("id", id),
 *     update: (list, id) => list.filter((n) => n.id !== id),
 *     errorMessage: "Suppression impossible",
 *   });
 *   del.mutate(notificationId);
 *
 * @param queryKey  Clé React Query de la liste à muter (peut matcher partiellement).
 * @param mutationFn Fonction qui exécute la mutation serveur.
 * @param update    Reducer pur qui applique la modif au cache localement.
 * @param errorMessage Texte de toast affiché en cas d'erreur (+ rollback auto).
 * @param onSettled Callback additionnel (ex. invalidation ciblée post-serveur).
 */
export function useOptimisticListMutation<TItem, TVars>(opts: {
  queryKey: QueryKey;
  mutationFn: (vars: TVars) => Promise<unknown>;
  update: (list: TItem[], vars: TVars) => TItem[];
  errorMessage?: string;
  onSuccess?: UseMutationOptions<unknown, Error, TVars>["onSuccess"];
  onSettled?: UseMutationOptions<unknown, Error, TVars>["onSettled"];
}) {
  const qc = useQueryClient();
  const { queryKey, mutationFn, update, errorMessage, onSuccess, onSettled } = opts;

  const snapshot = useCallback(
    () =>
      qc
        .getQueryCache()
        .findAll({ queryKey })
        .map((q) => ({ key: q.queryKey, data: q.state.data as TItem[] | undefined })),
    [qc, queryKey],
  );

  return useMutation({
    mutationFn,
    onMutate: async (vars: TVars) => {
      await qc.cancelQueries({ queryKey });
      const previous = snapshot();
      for (const { key, data } of previous) {
        if (Array.isArray(data)) qc.setQueryData(key, update(data, vars));
      }
      return { previous };
    },
    onError: (err, _vars, ctx) => {
      // Rollback exhaustif
      if (ctx?.previous) {
        for (const { key, data } of ctx.previous) qc.setQueryData(key, data);
      }
      if (errorMessage) toast.error(errorMessage, { description: err.message });
    },
    onSuccess,
    onSettled: (data, err, vars, ctx) => {
      // Le Realtime bus déclenche déjà l'invalidation, mais on force ici
      // pour couvrir les tables non-realtime.
      qc.invalidateQueries({ queryKey });
      onSettled?.(data, err, vars, ctx);
    },
  });
}
