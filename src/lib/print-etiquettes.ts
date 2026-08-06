import logoUrl from "@/assets/fabs-logo.png";
import { toast } from "sonner";

export type PrintLayout = "a4-portrait-auto";

/**
 * Ouvre une fenêtre d'impression dédiée pour une ou plusieurs étiquettes.
 * La mise en page est optimisée pour A4 Portrait :
 * - 1 étiquette -> 1 page pleine
 * - 2+ étiquettes -> 2 par page (disposition verticale)
 */
export function printEtiquettes(
  html: string,
  title = "Étiquettes colis",
  layout: PrintLayout = "a4-portrait-auto",
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

  const styles = `
  @page { size: A4 portrait; margin: 0; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; background: #fff; color: #000;
    font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  
  .sheet { display: block; width: 100%; min-height: 297mm; position: relative; }

  /* Conteneur d'une page A4 */
  .a4-page {
    width: 210mm;
    height: 297mm;
    page-break-after: always;
    break-after: page;
    position: relative;
    overflow: hidden;
  }

  /* Cas 1 étiquette par page (Page entière) */
  .single-label-page {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 15mm;
  }
  .single-label-page .etiquette-carton {
    width: 180mm !important;
    height: 260mm !important;
    border: 1px solid #eee;
  }

  /* Cas 2 étiquettes par page (Moitié A4) */
  .double-label-page {
    display: flex;
    flex-direction: column;
  }
  .label-half {
    height: 148.5mm;
    width: 210mm;
    padding: 10mm 15mm;
    position: relative;
    border-bottom: 0.2mm dashed #ccc;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .label-half:last-child { border-bottom: none; }
  
  .label-half .etiquette-carton {
    width: 180mm !important;
    height: 128mm !important;
    transform: scale(0.95); /* Légère réduction pour tenir proprement */
  }

  /* Repères de découpe et ciseaux pour le mode double */
  .crop-marks-v {
    position: absolute;
    top: 148.5mm;
    left: 0;
    right: 0;
    border-top: 0.2mm dashed #666;
    z-index: 100;
  }
  .cut-icon {
    position: absolute;
    left: 10mm;
    top: 148.5mm;
    transform: translateY(-50%);
    background: white;
    padding: 2px;
    font-size: 16pt;
    z-index: 101;
  }

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
