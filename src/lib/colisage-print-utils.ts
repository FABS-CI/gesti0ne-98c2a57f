import { buildEtiquettesPayload } from "@/lib/colisage-helpers";
import { buildEtiquettesPrintHtml } from "@/lib/etiquette-html";
import { printEtiquettes } from "@/lib/print-etiquettes";
import type { EtiquettePayload } from "@/components/colisage/EtiquetteCarton";
import type { BLDetail, ColisRow } from "@/lib/colisage-api";

/**
 * Génère le HTML des étiquettes sans dépendre du DOM affiché.
 */
export async function getEtiquettesHtml(etiquettes: EtiquettePayload[]): Promise<string> {
  return await buildEtiquettesPrintHtml(etiquettes);
}

/**
 * Déclenche l'impression automatique des étiquettes après validation du colisage.
 */
export async function triggerAutoPrintEtiquettes(colis: ColisRow[], bl: BLDetail) {
  const payload = buildEtiquettesPayload(colis, bl);
  if (payload.length === 0) return;

  const html = await buildEtiquettesPrintHtml(payload);
  if (html && html.trim() !== "") {
    printEtiquettes(html, `Étiquettes ${bl.reference}`, "a4-portrait-auto");
  } else {
    console.error("[triggerAutoPrintEtiquettes] HTML vide — aucune donnée d'étiquette");
  }
}
