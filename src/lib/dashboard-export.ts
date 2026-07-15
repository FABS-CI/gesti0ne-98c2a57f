import {
  drawHeader,
  drawFooter,
  addPageNumbers,
  getPdfChromeBodyTop,
  ensurePdfLogo,
} from "@/lib/pdf/pdfChrome";
import { getActiveTemplate } from "@/lib/pdf/pdfConfig";

export async function captureChartsNode(node: HTMLElement | null): Promise<string | null> {
  if (!node) return null;
  const bg = getComputedStyle(document.body).backgroundColor || "#ffffff";
  const { toPng } = await import("html-to-image");
  return toPng(node, { cacheBust: true, pixelRatio: 2, backgroundColor: bg });
}

export function downloadDataUrl(dataUrl: string, filename: string): void {
  const a = document.createElement("a");
  a.href = dataUrl;
  a.download = filename;
  a.click();
}

export async function exportDashboardPdf(dataUrl: string, periode: string): Promise<void> {
  const img = new Image();
  img.src = dataUrl;
  await new Promise((res) => (img.onload = res));
  await ensurePdfLogo();
  const { jsPDF } = await import("jspdf");
  const pdf = new jsPDF({ orientation: "portrait", unit: "mm", format: "a4" });
  const template = getActiveTemplate();
  const pageW = pdf.internal.pageSize.getWidth();
  const pageH = pdf.internal.pageSize.getHeight();
  const margin = 10;
  drawHeader(pdf, `Tableau de bord — ${periode} derniers jours`, template);
  drawFooter(pdf, "La Direction", template);
  const maxW = pageW - margin * 2;
  const imgW = maxW;
  const imgH = (img.height / img.width) * imgW;
  const finalH = Math.min(imgH, pageH - getPdfChromeBodyTop() - 54);
  const finalW = (img.width / img.height) * finalH;
  pdf.addImage(dataUrl, "PNG", margin, getPdfChromeBodyTop(), Math.min(finalW, maxW), finalH);
  addPageNumbers(pdf);
  pdf.save(`tableau-de-bord-${periode}j.pdf`);
}
