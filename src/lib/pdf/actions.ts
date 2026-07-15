/**
 * Helpers d'actions documents (Imprimer, Email) — utilisés par
 * les barres d'actions harmonisées des modules Commandes / Proformas /
 * Factures (§15 du cahier des charges).
 */
import { getOrCreatePdf } from "./pdfCache";
import { openPdfPreview } from "./preview-store";

export function printBlob(blob: Blob): void {
  const url = URL.createObjectURL(blob);
  const w = window.open(url, "_blank");
  if (!w) {
    // Pop-up bloquée — fallback : ouvrir simplement le PDF
    window.location.href = url;
    return;
  }
  const trigger = () => {
    try {
      w.focus();
      w.print();
    } catch {
      /* noop */
    }
  };
  w.addEventListener("load", trigger);
  // Sécurité si l'événement load est manqué (PDF natif)
  setTimeout(trigger, 1200);
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

/**
 * Variante cachée d'Imprimer : réutilise le même Blob que Visualiser /
 * Télécharger via `pdfCache` pour éviter une régénération et l'apparition
 * d'un téléchargement parasite. `window.print()` est déclenché dans le
 * nouvel onglet une fois le PDF chargé.
 */
export async function printCached(
  cacheKey: string,
  factory: () => Promise<Blob>,
  opts?: { title?: string; filename?: string },
): Promise<void> {
  openPdfPreview({
    title: opts?.title ?? "Aperçu du document",
    filename: opts?.filename ?? `${cacheKey}.pdf`,
    factory: () => getOrCreatePdf(cacheKey, factory),
    autoPrint: true,
  });
}

export async function viewCached(
  cacheKey: string,
  factory: () => Promise<Blob>,
  opts?: { title?: string; filename?: string },
): Promise<void> {
  openPdfPreview({
    title: opts?.title ?? "Aperçu du document",
    filename: opts?.filename ?? `${cacheKey}.pdf`,
    factory: () => getOrCreatePdf(cacheKey, factory),
  });
}

/** Ouvre un PDF dans un nouvel onglet pour visualisation. */
export function viewBlob(blob: Blob): void {
  const url = URL.createObjectURL(blob);
  const w = window.open(url, "_blank");
  if (!w) {
    window.location.href = url;
    return;
  }
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

/**
 * Ouvre une fenêtre SYNCHRONEMENT (dans le geste utilisateur du clic) puis
 * attend le blob et navigue vers son URL. Évite le blocage pop-up de Chrome
 * lorsque la génération du PDF est asynchrone.
 */
export async function viewBlobAsync(
  promise: Promise<Blob>,
  opts?: { title?: string; filename?: string },
): Promise<void> {
  openPdfPreview({
    title: opts?.title ?? "Aperçu du document",
    filename: opts?.filename ?? "document.pdf",
    factory: () => promise,
  });
}

export async function printBlobAsync(
  promise: Promise<Blob>,
  opts?: { title?: string; filename?: string },
): Promise<void> {
  openPdfPreview({
    title: opts?.title ?? "Aperçu du document",
    filename: opts?.filename ?? "document.pdf",
    factory: () => promise,
    autoPrint: true,
  });
}

export function emailDoc(opts: { to?: string; subject: string; body?: string }): void {
  const params = new URLSearchParams();
  params.set("subject", opts.subject);
  if (opts.body) params.set("body", opts.body);
  const href = `mailto:${opts.to ?? ""}?${params.toString()}`;
  window.location.href = href;
}
