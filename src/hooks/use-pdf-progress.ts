import { useRef, useState } from "react";
import { toast } from "sonner";
import { friendlyError } from '@/lib/friendly-error';

export type PdfMode = "preview" | "download";
export interface PdfProgress {
  pct: number;
  label: string;
  mode: PdfMode;
}

const STAGES: Array<[number, string]> = [
  [10, "Préparation des données…"],
  [30, "Mise en page A4 (en-tête, salarié)…"],
  [55, "Rubriques et sous-totaux…"],
  [75, "Cumuls annuels et signatures…"],
  [90, "Pagination multi-pages…"],
];

export function usePdfProgress() {
  const [pdfProgress, setPdfProgress] = useState<PdfProgress | null>(null);
  const cancelRef = useRef<{ cancelled: boolean } | null>(null);

  const runWithProgress = async (
    mode: PdfMode,
    build: () => Promise<Blob | null>,
    onDone: (blob: Blob) => void,
  ) => {
    const token = { cancelled: false };
    cancelRef.current = token;
    setPdfProgress({ pct: 5, label: "Initialisation…", mode });
    for (const [pct, label] of STAGES) {
      await new Promise((r) => setTimeout(r, 60));
      if (token.cancelled) {
        setPdfProgress(null);
        cancelRef.current = null;
        toast.message("Génération annulée");
        return;
      }
      setPdfProgress({ pct, label, mode });
    }
    if (token.cancelled) {
      setPdfProgress(null);
      cancelRef.current = null;
      return;
    }
    try {
      const blob = await build();
      if (blob) onDone(blob);
    } catch (e) {
      toast.error(friendlyError(e, "Erreur de génération"));
    } finally {
      setPdfProgress({ pct: 100, label: "Terminé", mode });
      setTimeout(() => setPdfProgress(null), 250);
      cancelRef.current = null;
    }
  };

  const cancelPdf = () => {
    if (cancelRef.current) cancelRef.current.cancelled = true;
  };

  return { pdfProgress, runWithProgress, cancelPdf };
}
