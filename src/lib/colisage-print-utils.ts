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
    const element = document.querySelector(`[data-colis-id="${e.colis_id}"]`);
    if (!element) {
      console.error("[getEtiquettesHtml] Élément DOM non trouvé pour colis_id:", e.colis_id);
    }
    const itemHtml = element?.outerHTML ?? "";
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
    
    const element1 = document.querySelector(`[data-colis-id="${e1.colis_id}"]`);
    if (!element1) console.error("[getEtiquettesHtml] Élément DOM non trouvé pour colis_id:", e1.colis_id);
    const item1Html = element1?.outerHTML ?? "";
    
    let item2Html = "";
    if (e2) {
      const element2 = document.querySelector(`[data-colis-id="${e2.colis_id}"]`);
      if (!element2) console.error("[getEtiquettesHtml] Élément DOM non trouvé pour colis_id:", e2.colis_id);
      item2Html = element2?.outerHTML ?? "";
    }

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
  
  console.log("[triggerAutoPrintEtiquettes] Lancement de l'impression automatique pour", payload.length, "étiquettes");
  
  // Augmentation du délai à 1200ms pour garantir le rendu complet du DOM et des QR codes
  setTimeout(() => {
    const html = getEtiquettesHtml(payload);
    if (html && html.trim() !== "") {
      console.log("[triggerAutoPrintEtiquettes] HTML généré avec succès, ouverture de la fenêtre d'impression");
      printEtiquettes(html, `Étiquettes ${bl.reference}`, "a4-portrait-auto");
    } else {
      console.error("[triggerAutoPrintEtiquettes] Échec de la génération du HTML (DOM peut-être non prêt)");
      // Tentative de secours après 2 secondes supplémentaires si vide
      setTimeout(() => {
        const retryHtml = getEtiquettesHtml(payload);
        if (retryHtml) {
          console.log("[triggerAutoPrintEtiquettes] Succès au deuxième essai");
          printEtiquettes(retryHtml, `Étiquettes ${bl.reference}`, "a4-portrait-auto");
        }
      }, 2000);
    }
  }, 1200);
}
