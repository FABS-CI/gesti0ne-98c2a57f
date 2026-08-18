import { Eye, ExternalLink, Printer } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EtiquetteCarton, type EtiquettePayload } from "@/components/colisage/EtiquetteCarton";
import { buildEtiquettesPrintHtml } from "@/lib/etiquette-html";
import { printEtiquettes } from "@/lib/print-etiquettes";

interface EtiquettesSectionProps {
  etiquettes: EtiquettePayload[];
  blReference: string;
}

export function EtiquettesSection({ etiquettes, blReference }: EtiquettesSectionProps) {
  const run = async (
    coliId: string | null | undefined,
    title: string,
    mode: "print" | "preview",
  ) => {
    const selected = coliId ? etiquettes.filter((e) => e.colis_id === coliId) : etiquettes;
    if (selected.length === 0) return;
    const html = await buildEtiquettesPrintHtml(selected);
    if (html) printEtiquettes(html, title, "a4-portrait-auto", mode);
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
            onClick={(ev) => {
              ev.preventDefault();
              void run(null, `Étiquettes ${blReference}`, "print");
            }}
          >
            <Printer className="mr-2 h-4 w-4" /> Imprimer tout ({etiquettes.length})
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={(ev) => {
              ev.preventDefault();
              void run(null, `Aperçu étiquettes ${blReference}`, "preview");
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
