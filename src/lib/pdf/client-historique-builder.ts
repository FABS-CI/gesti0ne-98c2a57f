import {
  drawHeader,
  drawFooter,
  addPageNumbers,
  ensurePdfLogo,
  getPdfChromeBodyTop,
  getPdfChromeFooterTop,
} from "@/lib/pdf/pdfChrome";
import { PDF_TABLE, getActiveTemplate } from "@/lib/pdf/pdfConfig";
import type { Client, ClientRelations } from "@/lib/clients-api";
import { formatFCFA } from "@/lib/format";

type Section = {
  titre: string;
  colonnes: string[];
  lignes: (string | number)[][];
};

function frDate(d: string | null | undefined): string {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("fr-FR");
}

/**
 * Génère un PDF « Historique complet » pour un client :
 * informations, solde, totaux, puis une section par type d'opération.
 */
export async function buildClientHistoriquePDF(
  client: Client,
  rel: ClientRelations,
): Promise<Blob> {
  const [{ default: jsPDF }, { default: autoTable }] = await Promise.all([
    import("jspdf"),
    import("jspdf-autotable"),
  ]);
  await ensurePdfLogo();
  const doc = new jsPDF({ orientation: "landscape", unit: "mm", format: "a4" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const marginX = 14;
  const template = getActiveTemplate();
  const titre = `Historique client — ${client.nom}`;

  drawHeader(doc, titre, template);
  drawFooter(doc, `Client ${client.reference}`, template);
  let cursorY = getPdfChromeBodyTop();

  // Bloc infos client
  doc.setFont("helvetica", "bold");
  doc.setFontSize(10);
  doc.setTextColor(30);
  doc.text("Informations client", marginX, cursorY);
  cursorY += 5;
  doc.setFont("helvetica", "normal");
  doc.setFontSize(9);
  const info: string[] = [
    `Référence : ${client.reference}`,
    `Nom : ${client.nom}`,
    `Type : ${client.type_client}`,
    `Représentant : ${client.representant ?? "—"}`,
    `Téléphone : ${client.telephone ?? "—"}`,
    `Email : ${client.email ?? "—"}`,
    `Ville : ${client.ville ?? "—"}`,
    `Adresse : ${client.adresse ?? "—"}`,
  ];
  const col1 = info.slice(0, 4);
  const col2 = info.slice(4);
  col1.forEach((l, i) => doc.text(l, marginX, cursorY + i * 4.5));
  col2.forEach((l, i) => doc.text(l, marginX + (pageWidth - marginX * 2) / 2, cursorY + i * 4.5));
  cursorY += Math.max(col1.length, col2.length) * 4.5 + 4;

  // Totaux
  const totalCmd = rel.commandes.reduce((s, c) => s + Number(c.montant_total), 0);
  const totalFact = rel.factures.reduce((s, f) => s + Number(f.montant_total), 0);
  const totalPaye = rel.paiements
    .filter((p) => p.statut === "valide")
    .reduce((s, p) => s + Number(p.montant), 0);
  const totalPaiementsAttente = rel.paiements
    .filter((p) => p.statut !== "valide" && p.statut !== "annule")
    .reduce((s, p) => s + Number(p.montant), 0);
  const totalAvoirs = rel.avoirs.reduce((s, a) => s + Number(a.montant), 0);
  const encours = rel.factures.reduce((s, f) => {
    if (f.statut === "annulee" || f.statut === "avoir") return s;
    const solde = Number(f.montant_total) - Number(f.montant_paye);
    return solde > 0 ? s + solde : s;
  }, 0);

  autoTable(doc, {
    startY: cursorY,
    margin: {
      left: marginX,
      right: marginX,
      bottom: doc.internal.pageSize.getHeight() - getPdfChromeFooterTop(doc) + 4,
    },
    head: [["Indicateur", "Valeur"]],
    body: [
      ["Solde client", formatFCFA(Number(client.solde))],
      ["Total commandes", formatFCFA(totalCmd)],
      ["Total facturé", formatFCFA(totalFact)],
      ["Total payé (validé)", formatFCFA(totalPaye)],
      ["Paiements en attente", formatFCFA(totalPaiementsAttente)],
      ["Total avoirs / retours", formatFCFA(totalAvoirs)],
      ["Encours (restant dû)", formatFCFA(encours)],
      ["Nombre de commandes", String(rel.commandes.length)],
      ["Nombre de factures", String(rel.factures.length)],
      ["Nombre de paiements", String(rel.paiements.length)],
      ["Nombre de livraisons", String(rel.livraisons.length)],
    ],
    styles: { fontSize: PDF_TABLE.bodyFontSize, cellPadding: 2.2, lineWidth: 0.1 },
    headStyles: PDF_TABLE.headStyles,
    bodyStyles: PDF_TABLE.bodyStyles,
    alternateRowStyles: { fillColor: [245, 247, 250] },
    didDrawPage: () => {
      drawHeader(doc, titre, template);
      drawFooter(doc, `Client ${client.reference}`, template);
    },
  });

  const sections: Section[] = [
    {
      titre: "Commandes",
      colonnes: ["Date", "Référence", "Statut", "Montant"],
      lignes: rel.commandes.map((c) => [
        frDate(c.date_commande),
        c.reference,
        c.statut,
        formatFCFA(Number(c.montant_total)),
      ]),
    },
    {
      titre: "Proformas",
      colonnes: ["Date", "Référence", "Statut", "Validité", "Montant"],
      lignes: rel.proformas.map((p) => [
        frDate(p.date_proforma),
        p.reference,
        p.statut,
        frDate(p.date_validite),
        formatFCFA(Number(p.montant_total)),
      ]),
    },
    {
      titre: "Factures",
      colonnes: ["Date", "Référence", "Statut", "Total", "Payé"],
      lignes: rel.factures.map((f) => [
        frDate(f.date_facture),
        f.reference,
        f.statut,
        formatFCFA(Number(f.montant_total)),
        formatFCFA(Number(f.montant_paye)),
      ]),
    },
    {
      titre: "Paiements",
      colonnes: ["Date", "Référence", "Mode", "Statut", "Montant"],
      lignes: rel.paiements.map((p) => [
        frDate(p.date_paiement),
        p.reference,
        p.mode_paiement,
        p.statut,
        formatFCFA(Number(p.montant)),
      ]),
    },
    {
      titre: "Bons de livraison",
      colonnes: ["Date émission", "Référence", "Statut", "Livraison", "Montant"],
      lignes: rel.bons_livraison.map((b) => [
        frDate(b.date_emission),
        b.reference,
        b.statut,
        frDate(b.date_livraison),
        formatFCFA(Number(b.montant_total)),
      ]),
    },
    {
      titre: "Livraisons",
      colonnes: ["Date", "Référence", "Statut", "Transporteur"],
      lignes: rel.livraisons.map((l) => [
        frDate(l.date_livraison),
        l.reference,
        l.statut,
        l.transporteur ?? "—",
      ]),
    },
    {
      titre: "Retours / Avoirs",
      colonnes: ["Date", "Référence", "Statut", "Motif", "Montant"],
      lignes: rel.avoirs.map((a) => [
        frDate(a.date_retour),
        a.reference,
        a.statut,
        a.motif ?? "—",
        formatFCFA(Number(a.montant)),
      ]),
    },
  ];

  for (const section of sections) {
    // @ts-expect-error - lastAutoTable injecté par jspdf-autotable
    const lastY: number = doc.lastAutoTable?.finalY ?? cursorY;
    const footerLimit = getPdfChromeFooterTop(doc) - 20;
    let sectionY = lastY + 8;
    if (sectionY > footerLimit) {
      doc.addPage();
      drawHeader(doc, titre, template);
      drawFooter(doc, `Client ${client.reference}`, template);
      sectionY = getPdfChromeBodyTop();
    }
    doc.setFont("helvetica", "bold");
    doc.setFontSize(10);
    doc.setTextColor(30);
    doc.text(`${section.titre} (${section.lignes.length})`, marginX, sectionY);
    const startY = sectionY + 2;
    autoTable(doc, {
      startY,
      head: [section.colonnes],
      body:
        section.lignes.length > 0
          ? section.lignes.map((r) => r.map((c) => (c === null || c === undefined ? "" : String(c))))
          : [["—", ...section.colonnes.slice(1).map(() => "")]],
      margin: {
        left: marginX,
        right: marginX,
        bottom: doc.internal.pageSize.getHeight() - getPdfChromeFooterTop(doc) + 4,
      },
      styles: { fontSize: PDF_TABLE.bodyFontSize, cellPadding: 2.2, lineWidth: 0.1 },
      headStyles: PDF_TABLE.headStyles,
      bodyStyles: PDF_TABLE.bodyStyles,
      alternateRowStyles: { fillColor: [245, 247, 250] },
      didDrawPage: () => {
        drawHeader(doc, titre, template);
        drawFooter(doc, `Client ${client.reference}`, template);
      },
    });
  }

  addPageNumbers(doc);
  return doc.output("blob");
}
