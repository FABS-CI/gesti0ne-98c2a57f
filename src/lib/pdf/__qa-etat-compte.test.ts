import { readFile, writeFile } from "node:fs/promises";
import { describe, expect, it } from "vitest";
import { generateEtatCompteClientPDF } from "@/lib/pdf/fabsTemplates";

describe("QA PDF état de compte", () => {
  it("génère le relevé bancaire chronologique", async () => {
    const originalFetch = globalThis.fetch;
    const logo = await readFile("src/assets/fabs-logo.png");
    globalThis.fetch = async () => new Response(logo, { status: 200 });
    const blob = await generateEtatCompteClientPDF({
      reference: "EC|2026|CLIENT-DEMO",
      client: {
        code: "CLI-000125",
        nom: "ÉTABLISSEMENT CLIENT DE DÉMONSTRATION",
        adresse: "Bingerville — Côte d’Ivoire",
        telephone: "+225 01 02 03 04 05",
        email: "client@example.ci",
        representant: "Responsable commercial",
      },
      lignes: [
        {
          date: "2026-01-05",
          type: "Facture",
          reference: "FAC-2026-00125",
          factureReference: "FAC-2026-00125",
          libelle: "Facture client FAC-2026-00125",
          debit: 450000,
        },
        {
          date: "2026-01-08",
          type: "Paiement",
          reference: "PAI-2026-00015",
          factureReference: "FAC-2026-00125",
          libelle: "Paiement de la facture FAC-2026-00125",
          credit: 200000,
        },
        {
          date: "2026-01-12",
          type: "Avoir",
          reference: "RET-2026-00003",
          factureReference: "FAC-2026-00125",
          libelle: "Retour sur facture FAC-2026-00125",
          credit: 50000,
        },
        {
          date: "2026-01-18",
          type: "Facture",
          reference: "FAC-2026-00130",
          factureReference: "FAC-2026-00130",
          libelle: "Facture client FAC-2026-00130",
          debit: 300000,
        },
      ],
    });
    const bytes = new Uint8Array(await blob.arrayBuffer());
    await writeFile("/mnt/documents/qa-etat-compte.pdf", bytes);
    globalThis.fetch = originalFetch;
    expect(bytes.length).toBeGreaterThan(1000);
  });
});