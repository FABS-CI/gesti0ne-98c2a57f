import { useEffect, useState } from "react";
import fabsLogoUrl from "@/assets/fabs-logo.png";
import { supabase } from "@/integrations/supabase/client";

export type EtiquettePayload = {
  commande: string | null;
  facture: string | null;
  bl: string;
  colis_id?: string | null;
  client: string | null;
  etablissement: string | null;
  representant: string | null;
  telephone: string | null;
  ville: string | null;
  adresse: string | null;
  nb_cartons: number;
  numero_carton: number;
  responsable: string | null;
  date: string;
  mode_acheminement: "livraison" | "expedition";
  livreur_nom?: string | null;
  livreur_telephone?: string | null;
  gare_depart?: string | null;
  ville_destination?: string | null;
  gare_responsable?: string | null;
  gare_telephone?: string | null;
  produits: { designation: string | null; quantite: number; cover_path?: string | null }[];
};

export function EtiquetteCarton({ data }: { data: EtiquettePayload }) {
  const [qr, setQr] = useState<string>("");
  const [logoDataUrl, setLogoDataUrl] = useState<string>(fabsLogoUrl);
  const [imageUrls, setImageUrls] = useState<Record<string, string>>({});

  useEffect(() => {
    console.log("[EtiquetteCarton] Rendu de l'étiquette:", data.colis_id, data.numero_carton);
  }, [data.colis_id, data.numero_carton]);

  useEffect(() => {
    fetch(fabsLogoUrl)
      .then((r) => r.blob())
      .then(
        (b) =>
          new Promise<string>((resolve, reject) => {
            const fr = new FileReader();
            fr.onerror = () => reject(fr.error);
            fr.onload = () => resolve(String(fr.result));
            fr.readAsDataURL(b);
          }),
      )
      .then(setLogoDataUrl)
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    const envBase = (import.meta.env.VITE_PUBLIC_URL as string | undefined)?.replace(/\/$/, "");
    const origin =
      envBase ||
      (typeof window !== "undefined" ? window.location.origin : "https://gesti-0ne.lovable.app");
    const url = data.colis_id
      ? `${origin}/carton/${data.colis_id}`
      : JSON.stringify({
          bl: data.bl,
          commande: data.commande,
          carton: `${data.numero_carton}/${data.nb_cartons}`,
        });
    
    import("qrcode")
      .then(({ default: QRCode }) =>
        QRCode.toDataURL(url, {
          margin: 1,
          width: 150,
          errorCorrectionLevel: "M",
        }),
      )
      .then(setQr)
      .catch(() => setQr(""));
  }, [data]);

  useEffect(() => {
    const loadImages = async () => {
      const urls: Record<string, string> = {};
      for (const p of data.produits) {
        if (p.cover_path && !urls[p.cover_path]) {
          try {
            const { data: imgData } = supabase.storage
              .from("produits")
              .getPublicUrl(p.cover_path);
            if (imgData?.publicUrl) {
              const res = await fetch(imgData.publicUrl);
              const blob = await res.blob();
              const dataUrl = await new Promise<string>((resolve) => {
                const fr = new FileReader();
                fr.onload = () => resolve(String(fr.result));
                fr.readAsDataURL(blob);
              });
              urls[p.cover_path] = dataUrl;
            }
          } catch (e) {
            console.error("Erreur chargement image produit:", e);
          }
        }
      }
      setImageUrls(urls);
    };
    loadImages();
  }, [data.produits]);

  const isExpedition = data.mode_acheminement === "expedition";
  const telephone = isExpedition ? data.gare_telephone || data.telephone : data.telephone;
  const modeLabel = isExpedition ? "EXPÉDITION" : "LIVRAISON DIRECTE";

  return (
    <div
      className="etiquette-carton bg-white text-black break-inside-avoid flex flex-col"
      data-colis-id={data.colis_id ?? ""}
      style={{
        width: "100%",
        minHeight: "148.5mm", // Important pour la visibilité
        fontFamily: 'ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
        padding: "8mm",
        border: "1px solid #000", // Bordure noire plus visible
        backgroundColor: "white",
        color: "black",
        position: "relative",
        zIndex: 10
      }}
    >
      {/* En-tête */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          borderBottom: "2px solid #000",
          paddingBottom: "4mm",
          marginBottom: "6mm",
        }}
      >
        <img src={logoDataUrl} alt="FABS-CI" style={{ height: "18mm", width: "auto" }} />
        <div style={{ textAlign: "right" }}>
          <div style={{ fontSize: "20pt", fontWeight: 900, letterSpacing: "0.1em" }}>ÉTIQUETAGE</div>
          <div style={{ fontSize: "10pt", color: "#555", marginTop: "1mm" }}>Fiche carton — FABS-CI Éditions</div>
        </div>
      </div>

      <div className="text-center" style={{ border: "2.5px solid #000", padding: "5mm", marginBottom: "6mm" }}>
        <div style={{ fontSize: "14pt", fontWeight: 700, letterSpacing: "0.15em" }}>CARTON</div>
        <div style={{ fontSize: "40pt", fontWeight: 900, lineHeight: 1 }}>
          {data.numero_carton} / {data.nb_cartons}
        </div>
      </div>

      {/* Infos principales */}
      <div style={{ fontSize: "12pt", lineHeight: 1.5 }}>
        <div style={{ background: "#1B2A57", color: "#fff", padding: "4mm", marginBottom: "5mm", textAlign: "center", fontWeight: 900, fontSize: "16pt" }}>
          MODE DE LIVRAISON : {modeLabel}
        </div>
        <InfoRow label="N° BL" value={data.bl} />
        {data.colis_id && <InfoRow label="N° Colisage" value={data.colis_id.slice(0, 8).toUpperCase()} />}
        <InfoRow label="N° Commande" value={data.commande ?? "—"} />
        <InfoRow label="Client" value={data.client ?? "—"} strong />
        <div style={{ padding: "3mm 0", borderBottom: "1px solid #ddd" }}>
          <div style={{ color: "#555", fontSize: "10pt", marginBottom: "1mm" }}>Responsable Achat / Contact</div>
          <div style={{ fontWeight: 800, fontSize: "12pt" }}>
            {data.representant ?? "—"}{telephone ? ` · ${telephone}` : ""}
          </div>
          <div style={{ marginTop: "1mm", fontSize: "12pt", fontWeight: 700, textTransform: "uppercase" }}>
            {data.ville || "—"}
          </div>
        </div>
      </div>

      {/* Section Produits */}
      <div style={{ marginTop: "4mm", flex: 1 }}>
        <div style={{ fontSize: "12pt", fontWeight: 700, borderBottom: "1.5px solid #000", paddingBottom: "1.5mm", marginBottom: "3mm" }}>
          PRODUITS & QUANTITÉS
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: "4mm" }}>
          {data.produits.map((p, i) => (
            <div key={i} style={{ display: "flex", gap: "6mm", alignItems: "start" }}>
              {p.cover_path && imageUrls[p.cover_path] && (
                <img src={imageUrls[p.cover_path]} alt="" style={{ width: "22mm", height: "28mm", objectFit: "contain", border: "1px solid #ddd" }} />
              )}
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: "12pt", fontWeight: 700 }}>{p.designation}</div>
                <div style={{ fontSize: "16pt", fontWeight: 900, marginTop: "1mm" }}>QUANTITÉ : {p.quantite} EXEMPLAIRES</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* QR Code */}
      <div style={{ marginTop: "auto", paddingTop: "5mm", textAlign: "center" }}>
        {qr && <img src={qr} alt="QR" style={{ width: "35mm", height: "35mm", margin: "0 auto" }} />}
      </div>
    </div>
  );
}

function InfoRow({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div style={{ display: "grid", gridTemplateColumns: "35mm 1fr", gap: "2mm", borderBottom: "1px solid #ddd", padding: "1.5mm 0" }}>
      <div style={{ color: "#555" }}>{label}</div>
      <div style={{ fontWeight: strong ? 800 : 600 }}>{value}</div>
    </div>
  );
}

function InfoRow({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div style={{ display: "grid", gridTemplateColumns: "35mm 1fr", gap: "2mm", borderBottom: "1px solid #ddd", padding: "1.5mm 0" }}>
      <div style={{ color: "#555" }}>{label}</div>
      <div style={{ fontWeight: strong ? 800 : 600 }}>{value}</div>
    </div>
  );
}
