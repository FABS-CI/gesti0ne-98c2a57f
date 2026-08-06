import { useEffect, useState } from "react";
import fabsLogoUrl from "@/assets/fabs-logo.png";

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
  produits: { designation: string | null; quantite: number }[];
};

export function EtiquetteCarton({ data }: { data: EtiquettePayload }) {
  const [qr, setQr] = useState<string>("");
  const [logoDataUrl, setLogoDataUrl] = useState<string>(fabsLogoUrl);
  useEffect(() => {
    // Convertit le logo en dataURL pour qu'il s'affiche dans la fenêtre
    // d'impression (nouveau document sans accès aux assets Vite hashés).
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
    // Base URL publique : FORCÉE sur le domaine publié pour que le QR soit
    // toujours scannable sans authentification, même si l'étiquette est
    // imprimée depuis la preview Lovable (protégée par auth-bridge).
    const envBase = (import.meta.env.VITE_PUBLIC_URL as string | undefined)?.replace(/\/$/, "");
    const origin =
      envBase ||
      (typeof window !== "undefined" ? window.location.origin : "https://gesti-0ne.lovable.app");
    // URL publique du carton (aucune auth). Fallback JSON si colis pas persisté.
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
          width: 150, // Taille réduite pour accélération
          errorCorrectionLevel: "M", // Équilibre vitesse/fiabilité
        }),
      )
      .then(setQr)
      .catch(() => setQr(""));
  }, [data]);

  const destination =
    data.mode_acheminement === "expedition"
      ? `${data.ville_destination ?? ""}${data.gare_depart ? ` (Gare ${data.gare_depart})` : ""}`
      : [data.adresse, data.ville].filter(Boolean).join(", ") || data.ville || "";

  const isExpedition = data.mode_acheminement === "expedition";
  const telephone = isExpedition
    ? data.gare_telephone || data.telephone
    : data.telephone || data.livreur_telephone;

  const modeLabel = isExpedition ? "EXPÉDITION" : "LIVRAISON DIRECTE";

  // Sticker plein A4 : sobre, sans logo/en-tête/pied ERP, informations en gras.
  return (
    <div
      className="etiquette-carton bg-white text-black break-inside-avoid flex flex-col"
      data-colis-id={data.colis_id ?? ""}
      style={{
        width: "100%",
        minHeight: "100%",
        fontFamily: 'ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
      }}
    >
      {/* En-tête : logo FABS + titre ETIQUETAGE */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          gap: "6mm",
          borderBottom: "2px solid #000",
          paddingBottom: "4mm",
          marginBottom: "6mm",
        }}
      >
        <img
          src={logoDataUrl}
          alt="FABS-CI"
          style={{ height: "20mm", width: "auto", objectFit: "contain" }}
        />
        <div style={{ textAlign: "right" }}>
          <div
            style={{
              fontSize: "22pt",
              fontWeight: 900,
              letterSpacing: "0.2em",
              lineHeight: 1,
            }}
          >
            ÉTIQUETAGE
          </div>
          <div style={{ fontSize: "9pt", color: "#555", marginTop: "1.5mm" }}>
            Fiche carton — FABS-CI Éditions
          </div>
        </div>
      </div>

      {/* Bandeau Carton X / Y — très visible */}
      <div
        className="text-center"
        style={{ border: "3px solid #000", padding: "8mm 4mm", marginBottom: "8mm" }}
      >
        <div style={{ fontSize: "14pt", fontWeight: 700, letterSpacing: "0.15em" }}>CARTON</div>
        <div style={{ fontSize: "48pt", fontWeight: 900, lineHeight: 1 }}>
          {data.numero_carton} / {data.nb_cartons}
        </div>
      </div>

      {/* Bloc informations principales */}
      <div style={{ fontSize: "13pt", lineHeight: 1.6 }}>
        {/* Mode de livraison — encadré orange très visible */}
        <div
          style={{
            background: "linear-gradient(90deg, #1D4ED8 0%, #2563EB 50%, #3B82F6 100%)",
            color: "#FFFFFF",
            padding: "6mm 5mm",
            marginBottom: "5mm",
            border: "2px solid #0B2E7A",
            textAlign: "center",
            fontWeight: 900,
            fontSize: "18pt",
            letterSpacing: "0.05em",
            textTransform: "uppercase",
            boxShadow: "0 2mm 4mm rgba(29,78,216,0.25)",
          }}
        >
          MODE DE LIVRAISON : {modeLabel}
        </div>
        <InfoRow label="N° Bon de Livraison" value={data.bl} strong />
        {data.colis_id && (
          <InfoRow label="N° Colisage" value={data.colis_id.slice(0, 8).toUpperCase()} mono />
        )}
        <InfoRow label="N° Commande" value={data.commande ?? "—"} strong />
        <InfoRow label="Client" value={data.etablissement ?? data.client ?? "—"} strong />
        <InfoRow label="Destination" value={destination || "—"} strong uppercase />
        {isExpedition ? (
          <>
            <InfoRow label="Tél. Chef de gare" value={data.gare_telephone ?? "—"} strong />
            <InfoRow label="Tél. Client" value={data.telephone ?? "—"} strong />
          </>
        ) : (
          <InfoRow label="Téléphone" value={telephone ?? "—"} strong />
        )}
      </div>

      {/* QR code central et imposant */}
      <div
        className="flex flex-col items-center justify-center"
        style={{ marginTop: "auto", paddingTop: "10mm", textAlign: "center" }}
      >
        {qr ? (
          <img
            src={qr}
            alt="QR carton"
            style={{
              width: "28mm",
              height: "28mm",
              display: "block",
              margin: "0 auto",
              imageRendering: "pixelated",
            }}
          />
        ) : (
          <div style={{ width: "28mm", height: "28mm", background: "#eee", margin: "0 auto" }} />
        )}
        <div
          style={{
            fontSize: "10pt",
            marginTop: "3mm",
            color: "#333",
            textAlign: "center",
          }}
        >
          Scanner pour consulter les informations du carton
        </div>
      </div>
    </div>
  );
}

function InfoRow({
  label,
  value,
  strong,
  mono,
  uppercase,
}: {
  label: string;
  value: string;
  strong?: boolean;
  mono?: boolean;
  uppercase?: boolean;
}) {
  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "40mm 1fr",
        gap: "4mm",
        borderBottom: "1px solid #ddd",
        padding: "2mm 0",
      }}
    >
      <div style={{ color: "#333" }}>{label}</div>
      <div
        style={{
          fontWeight: strong ? 800 : 500,
          fontFamily: mono ? "ui-monospace, monospace" : undefined,
          textTransform: uppercase ? "uppercase" : undefined,
        }}
      >
        {value}
      </div>
    </div>
  );
}
