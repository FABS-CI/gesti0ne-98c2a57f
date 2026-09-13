import fabsLogoUrl from "@/assets/fabs-logo.png";
import { supabase } from "@/integrations/supabase/client";
import type { EtiquettePayload } from "@/components/colisage/EtiquetteCarton";

/**
 * Génération autonome du HTML des étiquettes (indépendante du DOM).
 * Garantit que le contenu réel du carton + le QR code sont présents
 * en aperçu, à l'impression et dans le PDF.
 */

const esc = (v: unknown): string =>
  String(v ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");

async function toDataUrl(url: string): Promise<string> {
  const res = await fetch(url);
  const blob = await res.blob();
  return await new Promise<string>((resolve, reject) => {
    const fr = new FileReader();
    fr.onerror = () => reject(fr.error);
    fr.onload = () => resolve(String(fr.result));
    fr.readAsDataURL(blob);
  });
}

function qrUrlFor(e: EtiquettePayload): string {
  const envBase = (import.meta.env.VITE_PUBLIC_URL as string | undefined)?.replace(/\/$/, "");
  const origin =
    envBase || (typeof window !== "undefined" ? window.location.origin : "https://gesti0ne.lovable.app");
  return e.colis_id
    ? `${origin}/carton/${e.colis_id}`
    : JSON.stringify({
        bl: e.bl,
        commande: e.commande,
        carton: `${e.numero_carton}/${e.nb_cartons}`,
      });
}

function infoRow(label: string, value: string, strong = false): string {
  return `<div style="display:grid;grid-template-columns:35mm 1fr;gap:2mm;border-bottom:1px solid #ddd;padding:1.5mm 0">
    <div style="color:#555">${esc(label)}</div>
    <div style="font-weight:${strong ? 800 : 600}">${esc(value)}</div>
  </div>`;
}

function labelHtml(
  e: EtiquettePayload,
  qr: string,
  logo: string,
  images: Record<string, string>,
): string {
  const isExpedition = e.mode_acheminement === "expedition";
  const telephone = isExpedition ? e.gare_telephone || e.telephone : e.telephone;
  const modeLabel = e.mode_acheminement === "direct" ? "LIVRAISON DIRECTE" : 
                    e.mode_acheminement === "gare" ? "GARE / TRANSPORTEUR" : 
                    (e.mode_acheminement || "—").toUpperCase();

  const produits = (e.produits ?? [])
    .map((p) => {
      const img =
        p.cover_path && images[p.cover_path]
          ? `<img src="${images[p.cover_path]}" alt="" style="width:22mm;height:28mm;object-fit:contain;border:1px solid #ddd" />`
          : "";
      return `<div style="display:flex;gap:6mm;align-items:flex-start">
        ${img}
        <div style="flex:1">
          <div style="font-size:12pt;font-weight:700">${esc(p.nom || p.designation || "—")}</div>
          <div style="font-size:16pt;font-weight:900;margin-top:1mm">QUANTITÉ : ${esc(p.quantite)} EXEMPLAIRES</div>
        </div>
      </div>`;
    })
    .join("");

  return `<div class="etiquette-carton" data-colis-id="${esc(e.colis_id ?? "")}" style="width:100%;min-height:148.5mm;font-family:ui-sans-serif,system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;padding:8mm;border:1px solid #000;background:#fff;color:#000;display:flex;flex-direction:column;position:relative;box-sizing:border-box">
    <div style="display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #000;padding-bottom:4mm;margin-bottom:6mm">
      <img src="${logo}" alt="FABS-CI" style="height:18mm;width:auto" />
      <div style="text-align:right">
        <div style="font-size:20pt;font-weight:900;letter-spacing:0.1em">ÉTIQUETAGE</div>
        <div style="font-size:10pt;color:#555;margin-top:1mm">Fiche carton — FABS-CI Éditions</div>
      </div>
    </div>

    <div style="text-align:center;border:2.5px solid #000;padding:5mm;margin-bottom:6mm">
      <div style="font-size:14pt;font-weight:700;letter-spacing:0.15em">CARTON</div>
      <div style="font-size:40pt;font-weight:900;line-height:1">${esc(e.numero_carton)} / ${esc(e.nb_cartons)}</div>
    </div>

    <div style="font-size:12pt;line-height:1.5">
      <div style="background:#1B2A57;color:#fff;padding:4mm;margin-bottom:5mm;text-align:center;font-weight:900;font-size:16pt;-webkit-print-color-adjust:exact;print-color-adjust:exact">
        MODE DE LIVRAISON : ${esc(modeLabel)}
      </div>
      ${infoRow("N° BL", e.bl)}
      ${e.colis_id ? infoRow("N° Colisage", e.colis_id.slice(0, 8).toUpperCase()) : ""}
      ${infoRow("N° Commande", e.commande ?? "—")}
      ${infoRow("Client", e.client ?? "—", true)}
      <div style="padding:3mm 0;border-bottom:1px solid #ddd">
        <div style="color:#555;font-size:10pt;margin-bottom:1mm">Responsable Achat / Contact</div>
        <div style="font-weight:800;font-size:12pt">${esc(e.representant ?? "—")}${telephone ? ` · ${esc(telephone)}` : ""}</div>
        <div style="margin-top:1mm;font-size:12pt;font-weight:700;text-transform:uppercase">${esc(e.ville || "—")}</div>
      </div>
    </div>

    <div style="margin-top:4mm;flex:1">
      <div style="font-size:12pt;font-weight:700;border-bottom:1.5px solid #000;padding-bottom:1.5mm;margin-bottom:3mm">PRODUITS &amp; QUANTITÉS</div>
      <div style="display:flex;flex-direction:column;gap:4mm">${produits}</div>
    </div>

    <div style="margin-top:auto;padding-top:5mm;text-align:center">
      ${qr ? `<img src="${qr}" alt="QR" style="width:35mm;height:35mm;margin:0 auto;display:block" />` : `<div style="width:35mm;height:35mm;border:1px dashed #ccc;margin:0 auto;display:flex;align-items:center;justify-content:center;font-size:8pt;color:#999">QR CODE</div>`}
    </div>
  </div>`;
}

/**
 * Construit le HTML complet (pagination A4) pour un ensemble d'étiquettes.
 */
export async function buildEtiquettesPrintHtml(etiquettes: EtiquettePayload[]): Promise<string> {
  if (!etiquettes.length) return "";

  const { default: QRCode } = await import("qrcode");

  const logo = await toDataUrl(fabsLogoUrl).catch(() => fabsLogoUrl);

  const qrs = await Promise.all(
    etiquettes.map((e) =>
      QRCode.toDataURL(qrUrlFor(e), {
        margin: 1,
        width: 300,
        errorCorrectionLevel: "M",
        color: QR_COLOR_OPTS,
      }).catch(
        () => "",
      ),
    ),
  );

  const images: Record<string, string> = {};
  const paths = Array.from(
    new Set(
      etiquettes.flatMap((e) => (e.produits ?? []).map((p) => p.cover_path).filter(Boolean)),
    ),
  ) as string[];
  await Promise.all(
    paths.map(async (path) => {
      try {
        const { data } = supabase.storage.from("produits").getPublicUrl(path);
        if (data?.publicUrl) images[path] = await toDataUrl(data.publicUrl);
      } catch {
        /* image optionnelle */
      }
    }),
  );

  if (etiquettes.length === 1) {
    return `<div class="a4-page single-label-page">${labelHtml(etiquettes[0], qrs[0], logo, images)}</div>`;
  }

  let html = "";
  for (let i = 0; i < etiquettes.length; i += 2) {
    const e1 = etiquettes[i];
    const e2 = etiquettes[i + 1];
    html += `<div class="a4-page double-label-page">
      <div class="label-half">${labelHtml(e1, qrs[i], logo, images)}</div>
      ${e2 ? `<div class="crop-marks-v"></div><div class="cut-icon"></div><div class="label-half">${labelHtml(e2, qrs[i + 1], logo, images)}</div>` : ""}
    </div>`;
  }
  return html;
}
