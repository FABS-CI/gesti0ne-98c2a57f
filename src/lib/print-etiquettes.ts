import logoUrl from "@/assets/fabs-logo.png";
import { toast } from "sonner";

export type PrintLayout = "a4-one";

/**
 * Ouvre une fenêtre d'impression dédiée pour une ou plusieurs étiquettes.
 *
 * - `a6`   : une étiquette QR par page A6 (105 × 148 mm).
 * - `a4-4up` : jusqu'à 4 codes-barres par feuille A4 (2 colonnes × 2 lignes),
 *   avec marges régulières et espacement suffisant pour la découpe.
 */
export function printEtiquettes(
  html: string,
  title = "Étiquettes colis",
  layout: PrintLayout = "a4-one",
  mode: "print" | "preview" = "print",
): Window | null {
  const w = window.open("", "_blank", "width=800,height=900");
  if (!w) {
    toast.error(
      "Fenêtre bloquée par le navigateur. Autorisez les pop-ups pour ce site puis réessayez.",
      { duration: 6000 },
    );
    return null;
  }
  void layout;
  const styles = `
  @page { size: A4 portrait; margin: 0; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; background: #fff; color: #000;
    font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  .sheet { display: block; }
  .etiquette-carton {
    width: 210mm !important;
    min-height: 297mm !important;
    padding: 12mm 14mm !important;
    page-break-after: always;
    break-after: page;
    page-break-inside: avoid;
    break-inside: avoid;
  }
  .etiquette-carton:last-child { page-break-after: auto; break-after: auto; }
  img { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .preview-bar { position: fixed; top: 0; left: 0; right: 0; padding: 8px 12px;
    background: #111827; color: #fff; font-size: 13px; display: flex; gap: 8px;
    align-items: center; z-index: 9999; }
  .preview-bar button { background: #F97316; color: #000; border: 0;
    padding: 6px 12px; border-radius: 4px; cursor: pointer; font-weight: 600; }
  @media print { .preview-bar { display: none; } }
`;
  const autoPrint =
    mode === "print" ? `setTimeout(function () { window.focus(); window.print(); }, 250);` : "";
  const previewBar =
    mode === "preview"
      ? `<div class="preview-bar"><span>Aperçu — ${title}</span><button onclick="window.print()">Imprimer</button><button onclick="window.close()">Fermer</button></div>`
      : "";
  w.document.write(`<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8" />
<title>${title}</title>
<link rel="icon" href="${logoUrl}" />
<style>${styles}</style>
</head>
<body>
${previewBar}
<div class="sheet">${html}</div>
<script>
  window.addEventListener('load', function () { ${autoPrint} });
</script>
</body>
</html>`);
  w.document.close();
  return w;
}
