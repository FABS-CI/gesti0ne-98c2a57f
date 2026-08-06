import logoUrl from "@/assets/fabs-logo.png";
import { toast } from "sonner";

export type PrintLayout = "a4-one" | "a4-two-landscape";

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
  .sheet { display: block; width: 100%; height: 100%; position: relative; }

  /* Layout A4 standard (1 par page portrait) */
  .layout-a4-one .etiquette-carton {
    width: 210mm !important;
    min-height: 297mm !important;
    padding: 12mm 14mm !important;
    page-break-after: always;
    break-after: page;
  }

  /* Layout A4 Paysage (2 par page) */
  .layout-a4-two-landscape { width: 297mm; height: 210mm; overflow: hidden; position: relative; }
  @media print {
    .layout-a4-two-landscape-container { 
      width: 297mm; height: 210mm; 
      page-break-after: always; break-after: page; 
    }
    @page { size: A4 landscape; margin: 0; }
  }

  .layout-a4-two-landscape .etiquette-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    width: 297mm;
    height: 210mm;
    position: relative;
  }

  .layout-a4-two-landscape .etiquette-carton {
    width: 148.5mm !important;
    height: 210mm !important;
    padding: 8mm 10mm !important;
    border: none !important;
    position: relative;
    overflow: hidden;
  }

  /* Repères de découpe */
  .crop-marks {
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    pointer-events: none;
    z-index: 100;
  }
  .crop-line-v {
    position: absolute;
    left: 50%; top: 5mm; bottom: 5mm;
    border-left: 0.2mm dashed #ccc;
    transform: translateX(-50%);
  }
  .cut-icon {
    position: absolute;
    left: 50%; top: 50%;
    transform: translate(-50%, -50%);
    background: white;
    padding: 2px;
    font-size: 14pt;
  }
  .mark-corner {
    position: absolute;
    width: 10mm; height: 10mm;
    border: 0.1mm solid #bbb;
  }
  .mark-tl { top: 0; left: 0; border-right: 0; border-bottom: 0; }
  .mark-tr { top: 0; right: 0; border-left: 0; border-bottom: 0; }
  .mark-bl { bottom: 0; left: 0; border-right: 0; border-top: 0; }
  .mark-br { bottom: 0; right: 0; border-left: 0; border-top: 0; }

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
<div class="sheet layout-${layout}">${html}</div>
<script>
  window.addEventListener('load', function () { ${autoPrint} });
</script>
</body>
</html>`);
  w.document.close();
  return w;
}
