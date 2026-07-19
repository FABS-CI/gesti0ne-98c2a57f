import { useEffect, useRef, useState } from "react";

/**
 * Petit QR code SVG affiché à l'écran (et à l'impression). Utilise la
 * librairie `qrcode` déjà présente dans le projet.
 */
export function QrCode({ value, size = 72 }: { value: string; size?: number }) {
  const [dataUrl, setDataUrl] = useState<string | null>(null);
  useEffect(() => {
    let cancelled = false;
    import("qrcode")
      .then(({ default: QR }) => QR.toDataURL(value, { margin: 0, width: size * 2 }))
      .then((url) => {
        if (!cancelled) setDataUrl(url);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [value, size]);
  if (!dataUrl) return <div style={{ width: size, height: size }} />;
  return (
    <img
      src={dataUrl}
      alt={`QR ${value}`}
      style={{ width: size, height: size }}
      className="print:block"
    />
  );
}

/**
 * Code-barres CODE128 SVG.
 */
export function Barcode({
  value,
  width = 180,
  height = 40,
}: {
  value: string;
  width?: number;
  height?: number;
}) {
  const ref = useRef<SVGSVGElement>(null);
  useEffect(() => {
    let cancelled = false;
    import("jsbarcode")
      .then(({ default: JsBarcode }) => {
        if (cancelled || !ref.current) return;
        try {
          JsBarcode(ref.current, value, {
            format: "CODE128",
            displayValue: true,
            fontSize: 10,
            margin: 0,
            height,
            width: 1.4,
            background: "#ffffff",
            lineColor: "#000000",
          });
        } catch {
          /* ignore */
        }
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [value, height]);
  return <svg ref={ref} style={{ width, height: height + 14 }} />;
}
