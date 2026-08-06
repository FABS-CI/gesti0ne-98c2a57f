import { Eye, ExternalLink, Printer } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EtiquetteCarton, type EtiquettePayload } from "@/components/colisage/EtiquetteCarton";
import { printEtiquettes } from "@/lib/print-etiquettes";

interface EtiquettesSectionProps {
  etiquettes: EtiquettePayload[];
  blReference: string;
}

export function EtiquettesSection({ etiquettes, blReference }: EtiquettesSectionProps) {
  const getHtml = (coliId?: string | null) => {
    const selectedEtiquettes = coliId 
      ? etiquettes.filter(e => e.colis_id === coliId)
      : etiquettes;

    if (selectedEtiquettes.length === 0) return "";

    // Cas 1 : Une seule étiquette -> Page A4 Portrait centrée
    if (selectedEtiquettes.length === 1) {
      const e = selectedEtiquettes[0];
      const itemHtml = document.querySelector(`[data-colis-id="${e.colis_id}"]`)?.outerHTML ?? "";
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
      
      const item1Html = document.querySelector(`[data-colis-id="${e1.colis_id}"]`)?.outerHTML ?? "";
      const item2Html = e2 ? (document.querySelector(`[data-colis-id="${e2.colis_id}"]`)?.outerHTML ?? "") : "";

      finalHtml += `
        <div class="a4-page double-label-page">
          <div class="label-half">${item1Html}</div>
          ${e2 ? `<div class="crop-marks-v"></div><div class="cut-icon">✂️</div>` : ""}
          <div class="label-half">${item2Html}</div>
        </div>
      `;
    }
    return finalHtml;
  };

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between print:hidden">
        <CardTitle>Étiquettes générées</CardTitle>
        <div className="flex gap-2">
          <Button
            variant="default"
            size="sm"
            onClick={() => {
              const h = getHtml();
              if (h) printEtiquettes(h, `Étiquettes ${blReference}`, "a4-portrait-auto");
            }}
          >
            <Printer className="mr-2 h-4 w-4" /> Imprimer les étiquettes ({etiquettes.length})
          </Button>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              const h = getHtml();
              if (h) printEtiquettes(h, `Aperçu étiquettes ${blReference}`, "a4-portrait-auto", "preview");
            }}
          >
            <Eye className="mr-2 h-4 w-4" /> Aperçu
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        <div className="grid gap-6 grid-cols-1 xl:grid-cols-2 print:grid-cols-1 print:gap-0">
          {etiquettes.map((e, i) => (
            <div key={i} className="flex flex-col items-center gap-2">
              <div className="w-full max-w-full overflow-x-auto print:overflow-visible rounded-md border bg-muted/30 p-2 print:border-0 print:bg-transparent print:p-0">
                <div className="mx-auto" style={{ width: "148.5mm" }}>
                  <EtiquetteCarton data={e} />
                </div>
              </div>
              <div className="flex flex-wrap justify-center gap-2 print:hidden">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
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
                    onClick={() => window.open(`/carton/${e.colis_id}`, "_blank")}
                  >
                    <ExternalLink className="mr-2 h-4 w-4" /> Prévisualiser QR
                  </Button>
                )}
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
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
                  <Eye className="mr-2 h-4 w-4" /> Aperçu carton {e.numero_carton}
                </Button>
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
