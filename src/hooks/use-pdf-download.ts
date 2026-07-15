import { useCallback, useState } from "react";
import { toast } from "sonner";
import { downloadBlob } from "@/lib/pdf/fabsTemplates";
import { verifyDocument, type DocKind } from "@/lib/pdf/verifyDocument";
import type { DocBase } from "@/lib/pdf/fabsTemplates";

type RowState = {
  loading: boolean;
  progress: number; // 0-100
  error: string | null;
};

const IDLE: RowState = { loading: false, progress: 0, error: null };

export function usePdfDownload() {
  const [states, setStates] = useState<Record<string, RowState>>({});

  const set = useCallback((id: string, patch: Partial<RowState>) => {
    setStates((s) => ({ ...s, [id]: { ...(s[id] ?? IDLE), ...patch } }));
  }, []);

  const getState = useCallback((id: string): RowState => states[id] ?? IDLE, [states]);

  /**
   * Génère et télécharge un PDF avec état de chargement, progression et
   * gestion d'erreur par ligne. Si `verify` est fourni, lance le contrôle
   * automatisé (QR JSON + mise en page) avant le téléchargement.
   */
  const download = useCallback(
    async (
      id: string,
      generate: () => Promise<Blob>,
      filename: string,
      verify?: { type: DocKind; data: DocBase },
    ) => {
      set(id, { loading: true, progress: 10, error: null });
      try {
        if (verify) {
          const result = verifyDocument(verify.type, verify.data);
          if (!result.ok) {
            const msg = result.issues
              .map(
                (i) =>
                  `${i.champ}: attendu ${JSON.stringify(i.attendu)}, reçu ${JSON.stringify(i.recu)}`,
              )
              .join(" • ");
            throw new Error(`Contrôle conformité échoué — ${msg}`);
          }
        }
        set(id, { progress: 40 });
        const blob = await generate();
        set(id, { progress: 80 });
        downloadBlob(blob, filename);
        set(id, { progress: 100 });
        setTimeout(() => set(id, { loading: false, progress: 0 }), 400);
      } catch (e) {
        const message = e instanceof Error ? e.message : "Erreur lors de la génération du PDF";
        set(id, { loading: false, progress: 0, error: message });
        toast.error(message);
      }
    },
    [set],
  );

  return { getState, download };
}
