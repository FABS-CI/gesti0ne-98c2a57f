import { Eye, ExternalLink, Printer } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EtiquetteCarton, type EtiquettePayload } from "@/components/colisage/EtiquetteCarton";
import { printEtiquettes } from "@/lib/print-etiquettes";
import { useEffect } from "react";

interface EtiquettesSectionProps {
  etiquettes: EtiquettePayload[];
  blReference: string;
}

export function EtiquettesSection({ etiquettes, blReference }: EtiquettesSectionProps) {
  useEffect(() => {
    console.log("[EtiquettesSection] Monté avec", etiquettes.length, "étiquettes");
  }, [etiquettes]);

  const getHtml = (coliId?: string | null) => {
    const selectedEtiquettes = coliId 
      ? etiquettes.filter(e => e.colis_id === coliId)
      : etiquettes;

    if (selectedEtiquettes.length === 0) {
      console.warn("[EtiquettesSection] Aucune étiquette sélectionnée pour impression");
      return "";
    }

    console.log("[EtiquettesSection] Génération HTML pour", selectedEtiquettes.length, "étiquettes");

    // Cas 1 : Une seule étiquette -> Page A4 Portrait centrée
    if (selectedEtiquettes.length === 1) {
      const e = selectedEtiquettes[0];
      const element = document.querySelector(`[data-colis-id="${e.colis_id}"]`);
      if (!element) {
        console.error("[EtiquettesSection] Élément DOM non trouvé pour colis_id:", e.colis_id);
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
    for (let i = 0; i < selectedEtiquettes.length; i += 2) {
      const e1 = selectedEtiquettes[i];
      const e2 = selectedEtiquettes[i + 1];
      
      const element1 = document.querySelector(`[data-colis-id="${e1.colis_id}"]`);
      if (!element1) console.error("[EtiquettesSection] Élément DOM non trouvé pour colis_id:", e1.colis_id);
      const item1Html = element1?.outerHTML ?? "";
      
      let item2Html = "";
      if (e2) {
        const element2 = document.querySelector(`[data-colis-id="${e2.colis_id}"]`);
        if (!element2) console.error("[EtiquettesSection] Élément DOM non trouvé pour colis_id:", e2.colis_id);
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
  };

  return (
    <Card className="shadow-lg border-primary/20">
      <CardHeader className="flex flex-row items-center justify-between print:hidden border-b pb-4">
        <div>
          <CardTitle className="text-xl font-bold text-primary">Étiquettes générées</CardTitle>
          <p className="text-sm text-muted-foreground mt-1">
            {etiquettes.length} étiquette{etiquettes.length > 1 ? 's' : ''} prête{etiquettes.length > 1 ? 's' : ''} pour l'impression
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            variant="default"
            size="sm"
            className="bg-primary hover:bg-primary/90"
            onClick={(e) => {
              e.preventDefault();
              const h = getHtml();
              if (h) printEtiquettes(h, `Étiquettes ${blReference}`, "a4-portrait-auto");
            }}
          >
            <Printer className="mr-2 h-4 w-4" /> Imprimer tout ({etiquettes.length})
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={(e) => {
              e.preventDefault();
              const h = getHtml();
              if (h) printEtiquettes(h, `Aperçu étiquettes ${blReference}`, "a4-portrait-auto", "preview");
            }}
          >
            <Eye className="mr-2 h-4 w-4" /> Aperçu global
          </Button>
        </div>
      </CardHeader>
      <CardContent className="pt-6">
        <div className="grid gap-8 grid-cols-1 xl:grid-cols-2 print:grid-cols-1 print:gap-0">
          {etiquettes.map((e, i) => (
            <div key={i} className="flex flex-col items-center gap-4 p-4 rounded-xl bg-muted/20 border border-muted-foreground/10 hover:border-primary/30 transition-colors">
              <div className="w-full overflow-x-auto rounded-lg shadow-sm border bg-white p-4">
                <div className="mx-auto" style={{ width: "148.5mm", minHeight: "148.5mm" }}>
                  <EtiquetteCarton data={e} />
                </div>
              </div>
              <div className="flex flex-wrap justify-center gap-3 print:hidden w-full pt-2 border-t border-muted-foreground/10">
                <Button
                  variant="secondary"
                  size="sm"
                  className="flex-1 min-w-[140px]"
                  onClick={(e_btn) => {
                    e_btn.preventDefault();
                    const h = getHtml(e.colis_id);
                    if (h)
                      printEtiquettes(
                        h,
                        `Sticker ${blReference} ${e.numero_carton}/${e.nb_cartons}`,
                        "a4-portrait-auto",
                      );
                  }}
                >
                  <Printer className="mr-2 h-4 w-4" /> Imprimer A4
                </Button>
                {e.colis_id && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="flex-1 min-w-[140px]"
                    onClick={(e_btn) => { e_btn.preventDefault(); window.open(`/carton/${e.colis_id}`, "_blank"); }}
                  >
                    <ExternalLink className="mr-2 h-4 w-4" /> Page Tracking
                  </Button>
                )}
                <Button
                  variant="outline"
                  size="sm"
                  className="flex-1 min-w-[140px]"
                  onClick={(e_btn) => {
                    e_btn.preventDefault();
                    const h = getHtml(e.colis_id);
                    if (h)
                      printEtiquettes(
                        h,
                        `Aperçu ${blReference} ${e.numero_carton}/${e.nb_cartons}`,
                        "a4-portrait-auto",
                        "preview",
                      );
                  }}
                >
                  <Eye className="mr-2 h-4 w-4" /> Aperçu
                </Button>
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
