import { useCallback, useState } from "react";
import {
  ConfirmDeleteDialog,
  type ConfirmDeleteDialogProps,
} from "@/components/ui/confirm-delete-dialog";

type Options = Omit<
  ConfirmDeleteDialogProps,
  "open" | "onOpenChange" | "onConfirm" | "pending"
>;

/**
 * Confirmation de suppression impérative.
 *
 * ```tsx
 * const { confirm, dialog } = useConfirmDelete();
 * const motif = await confirm({ title: "...", entityLabel: "..." });
 * if (motif === false) return; // annulé
 * mutate(motif);
 * // ...
 * return <>{content}{dialog}</>;
 * ```
 *
 * `confirm()` retourne `false` si l'utilisateur annule, sinon le motif saisi
 * (ou `null` quand `motifRequired` n'est pas activé).
 */
export function useConfirmDelete() {
  const [state, setState] = useState<{
    opts: Options;
    resolve: (value: string | null | false) => void;
  } | null>(null);

  const confirm = useCallback((opts: Options) => {
    return new Promise<string | null | false>((resolve) => {
      setState({ opts, resolve });
    });
  }, []);

  const dialog = state ? (
    <ConfirmDeleteDialog
      {...state.opts}
      open
      onOpenChange={(open) => {
        if (!open) {
          state.resolve(false);
          setState(null);
        }
      }}
      onConfirm={(motif) => {
        state.resolve(motif);
        setState(null);
      }}
    />
  ) : null;

  return { confirm, dialog };
}