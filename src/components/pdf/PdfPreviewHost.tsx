import { useEffect, useRef, useState } from "react";
import { PdfPreviewModal } from "./PdfPreviewModal";
import { subscribePdfPreview, type PdfPreviewRequest } from "@/lib/pdf/preview-store";
import { printBlob } from "@/lib/pdf/actions";

/**
 * Hôte global d'aperçu PDF. Monté une fois dans le root, il écoute
 * `openPdfPreview()` et affiche la modale d'aperçu intégré.
 */
export function PdfPreviewHost() {
  const [req, setReq] = useState<PdfPreviewRequest | null>(null);
  const [open, setOpen] = useState(false);
  const printedRef = useRef(false);

  useEffect(
    () =>
      subscribePdfPreview((r) => {
        printedRef.current = false;
        setReq(r);
        setOpen(true);
      }),
    [],
  );

  // Charge une seule fois par requête, mémorise le blob pour l'auto-print.
  const load = req
    ? async () => {
        const blob = await req.factory();
        if (req.autoPrint && !printedRef.current) {
          printedRef.current = true;
          // Laisse l'iframe s'afficher, puis déclenche l'impression via un
          // popup dédié (le navigateur n'imprime pas fiablement l'iframe cross
          // à cause du PDF viewer natif).
          setTimeout(() => printBlob(blob), 400);
        }
        return blob;
      }
    : async () => new Blob();

  return (
    <PdfPreviewModal
      open={open}
      onOpenChange={setOpen}
      title={req?.title ?? "Aperçu"}
      filename={req?.filename ?? "document.pdf"}
      load={load}
    />
  );
}
