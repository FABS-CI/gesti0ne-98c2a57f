/**
 * URL publique stable utilisée dans les QR codes des documents (Facture, Proforma).
 * Les PDF étant imprimés puis scannés hors de l'application, l'URL ne doit JAMAIS
 * pointer vers un domaine de preview / localhost (lien mort une fois imprimé).
 */
export const PUBLIC_VERIFY_BASE_URL = "https://gesti0ne.lovable.app";

function isEphemeralOrigin(origin: string): boolean {
  return (
    origin.includes("localhost") ||
    origin.includes("127.0.0.1") ||
    origin.includes("id-preview") ||
    origin.includes("lovableproject.com") ||
    origin.includes("sandbox") ||
    origin.startsWith("capacitor://") ||
    origin.startsWith("file://")
  );
}

export function buildQrUrl(reference: string): string {
  const origin =
    typeof window !== "undefined" && window.location?.origin ? window.location.origin : "";
  const base = origin && !isEphemeralOrigin(origin) ? origin : PUBLIC_VERIFY_BASE_URL;
  return `${base}/verify/${encodeURIComponent(reference)}`;
}
