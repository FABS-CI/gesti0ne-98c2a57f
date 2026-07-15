import { useEffect, useRef } from "react";
import type { EtiquettePayload } from "./EtiquetteCarton";

/**
 * Étiquette code-barres carton — format standardisé pour impression A4 (4 par
 * page, disposition 2×2). Toutes les étiquettes ont la même taille, la même
 * police et le même positionnement afin de garantir une homogénéité parfaite.
 */
export function EtiquetteBarcode({
  data,
  depot,
}: {
  data: EtiquettePayload;
  depot?: string | null;
}) {
  const svgRef = useRef<SVGSVGElement>(null);

  // Valeur encodée : COMMANDE-CARTON/TOTAL (fallback BL si pas de commande).
  const code = `${(data.commande ?? data.bl ?? "COLIS").replace(/\s+/g, "")}-${data.numero_carton}-${data.nb_cartons}`;

  useEffect(() => {
    if (!svgRef.current) return;
    let cancelled = false;
    import("jsbarcode")
      .then(({ default: JsBarcode }) => {
        if (cancelled || !svgRef.current) return;
        try {
          JsBarcode(svgRef.current, code, {
            format: "CODE128",
            displayValue: false,
            margin: 0,
            height: 70,
            width: 2,
            background: "#ffffff",
            lineColor: "#000000",
          });
        } catch {
          /* code invalide : on laisse le SVG vide */
        }
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [code]);

  const destination =
    data.mode_acheminement === "expedition" ? (data.ville_destination ?? "") : (data.ville ?? "");

  const date = new Date(data.date).toLocaleDateString("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });

  return (
    <div
      className="etiquette-barcode border-2 border-black bg-white text-black break-inside-avoid flex flex-col justify-between"
      data-barcode-colis-id={data.colis_id ?? ""}
      style={{
        width: "95mm",
        height: "138mm",
        padding: "6mm",
        fontFamily: 'ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
      }}
    >
      {/* En-tête : commande + carton */}
      <div className="flex items-start justify-between gap-3 border-b-2 border-black pb-2">
        <div>
          <div className="text-[9px] uppercase tracking-wide text-neutral-600">Commande</div>
          <div className="text-base font-black leading-tight">{data.commande ?? "—"}</div>
        </div>
        <div className="text-right">
          <div className="text-[9px] uppercase tracking-wide text-neutral-600">Carton</div>
          <div className="text-2xl font-black leading-none">
            {data.numero_carton}/{data.nb_cartons}
          </div>
        </div>
      </div>

      {/* Infos client */}
      <div className="mt-2 text-[10px] space-y-1 leading-tight">
        <div>
          <span className="uppercase text-neutral-600">Client :</span>{" "}
          <span className="font-semibold">{data.etablissement ?? data.client ?? "—"}</span>
        </div>
        <div>
          <span className="uppercase text-neutral-600">Destination :</span>{" "}
          <span className="font-semibold uppercase">{destination || "—"}</span>
        </div>
        {depot ? (
          <div>
            <span className="uppercase text-neutral-600">Dépôt :</span>{" "}
            <span className="font-semibold">{depot}</span>
          </div>
        ) : null}
      </div>

      {/* Zone code-barres — centrée, marge blanche garantie */}
      <div
        className="flex flex-col items-center justify-center bg-white"
        style={{ padding: "4mm 2mm" }}
      >
        <svg ref={svgRef} style={{ width: "80mm", height: "24mm" }} />
        <div className="mt-1 text-center font-mono text-[10px] tracking-wider">{code}</div>
      </div>

      {/* Pied : date + préparateur */}
      <div className="border-t border-black pt-1 text-[9px] flex justify-between text-neutral-700">
        <span>
          <span className="uppercase">Préparé le </span>
          <span className="font-semibold text-black">{date}</span>
        </span>
        {data.responsable ? (
          <span>
            <span className="uppercase">Prépar. </span>
            <span className="font-semibold text-black">{data.responsable}</span>
          </span>
        ) : null}
      </div>
    </div>
  );
}
