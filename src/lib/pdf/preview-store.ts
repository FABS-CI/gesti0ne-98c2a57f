/**
 * Petit bus global pour ouvrir un aperçu PDF intégré depuis n'importe où
 * (module non-React). Un composant hôte (PdfPreviewHost) s'abonne et affiche
 * la modale. Évite les fenêtres popup bloquées par Chrome.
 */
export type PdfPreviewRequest = {
  title: string;
  filename: string;
  factory: () => Promise<Blob>;
  autoPrint?: boolean;
};

type Listener = (req: PdfPreviewRequest) => void;

const listeners = new Set<Listener>();

export function subscribePdfPreview(fn: Listener): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function openPdfPreview(req: PdfPreviewRequest): void {
  if (listeners.size === 0) {
    // Fallback : aucun hôte monté (ex. SSR ou route publique) → ouvre onglet.
    req.factory().then((blob) => {
      const url = URL.createObjectURL(blob);
      const w = window.open(url, "_blank");
      if (!w) window.location.href = url;
      setTimeout(() => URL.revokeObjectURL(url), 60_000);
    });
    return;
  }
  listeners.forEach((fn) => fn(req));
}
