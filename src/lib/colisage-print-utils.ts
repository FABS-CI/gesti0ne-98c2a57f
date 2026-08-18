import { buildEtiquettesPayload } from "@/lib/colisage-helpers";
import { printEtiquettes } from "@/lib/print-etiquettes";
import type { EtiquettePayload } from "@/components/colisage/EtiquetteCarton";
import type { BLDetail, ColisRow } from "@/lib/colisage-api";

/**
 * Récupère le HTML des étiquettes pour l'impression, 
 * en utilisant la même logique que EtiquettesSection.
 */
export function getEtiquettesHtml(etiquettes: EtiquettePayload[]): string {
  if (etiquettes.length === 0) return "";

  // Cas 1 : Une seule étiquette -> Page A4 Portrait centrée
  if (etiquettes.length === 1) {
    const e = etiquettes[0];
    const itemHtml = document.querySelector(`[data-colis-id="${e.colis_id}"]`)?.outerHTML ?? "";
    return `
      <div class="a4-page single-label-page">
        ${itemHtml}
      </div>
    `;
  }

  // Cas 2 : Plusieurs étiquettes -> 2 par page (A4 Portrait vertical)
  let finalHtml = "";
  for (let i = 0; i < etiquettes.length; i += 2) {
    const e1 = etiquettes[i];
    const e2 = etiquettes[i + 1];
    
    const item1Html = document.querySelector(`[data-colis-id="${e1.colis_id}"]`)?.outerHTML ?? "";
    const item2Html = e2 ? (document.querySelector(`[data-colis-id="${e2.colis_id}"]`)?.outerHTML ?? "") : "";

    finalHtml += `
      <div class="a4-page double-label-page">
        <div class="label-half">${item1Html}</div>
        ${e2 ? `<div class="crop-marks-v"></div><div class="cut-icon"></div>` : ""}
        <div class="label-half">${item2Html}</div>
      </div>
    `;
  }
  return finalHtml;
}

/**
 * Déclenche l'impression automatique des étiquettes pour un BL donné.
 */
export function triggerAutoPrintEtiquettes(colis: ColisRow[], bl: BLDetail) {
  const payload = buildEtiquettesPayload(colis, bl);
  
  // Délai de 800ms pour garantir que le DOM est totalement stable et que les QR codes sont générés
  setTimeout(() => {
    const html = getEtiquettesHtml(payload);
    if (html) {
      printEtiquettes(html, `Étiquettes ${bl.reference}`, "a4-portrait-auto");
    }
  }, 800);
}
