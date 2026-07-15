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
  const getHtml = (coliId?: string | null) =>
    coliId
      ? (document.querySelector(`[data-colis-id="${coliId}"]`)?.outerHTML ?? "")
      : etiquettes
          .map((e) => document.querySelector(`[data-colis-id="${e.colis_id}"]`)?.outerHTML ?? "")
          .join("");

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
              if (h) printEtiquettes(h, `Étiquettes ${blReference}`, "a4-one");
            }}
          >
            <Printer className="mr-2 h-4 w-4" /> Imprimer A4 (1/page × {etiquettes.length})
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              const h = getHtml();
              if (h) printEtiquettes(h, `Aperçu étiquettes ${blReference}`, "a4-one", "preview");
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
                <div className="mx-auto" style={{ width: "190mm" }}>
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
                        "a4-one",
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
                        "a4-one",
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
