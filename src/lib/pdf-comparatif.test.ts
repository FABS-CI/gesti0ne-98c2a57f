import { describe, it, expect } from "vitest";
import { buildPdfMeta, type ComparatifRow } from "./pdf-comparatif";

const rows: ComparatifRow[] = [
  {
    code: "2024",
    nbCommandes: 10,
    nbFactures: 8,
    ca: 1_000_000,
    encaisse: 800_000,
    achats: 400_000,
    resultat: 600_000,
  },
  {
    code: "2025",
    nbCommandes: 15,
    nbFactures: 12,
    ca: 1_500_000,
    encaisse: 1_200_000,
    achats: 500_000,
    resultat: 1_000_000,
  },
];

describe("buildPdfMeta", () => {
  it("inclut horodatage, utilisateur et contexte dans la meta", () => {
    const meta = buildPdfMeta({
      userEmail: "user@test.com",
      timestamp: "04/07/2026 10:30",
      rows,
      sortKey: "ca",
      sortDir: "desc",
      showPct: false,
    });
    const labels = meta.summary.map((s) => s.label);
    expect(labels).toContain("Généré le");
    expect(labels).toContain("Généré par");
    expect(labels).toContain("Contexte");
    expect(meta.summary.find((s) => s.label === "Généré par")?.value).toBe("user@test.com");
    expect(meta.summary.find((s) => s.label === "Généré le")?.value).toBe("04/07/2026 10:30");
  });

  it("liste les exercices dans l'ordre affiché", () => {
    const meta = buildPdfMeta({
      userEmail: "u@x",
      timestamp: "t",
      rows,
      sortKey: "ca",
      sortDir: "desc",
      showPct: false,
    });
    expect(meta.summary.find((s) => s.label === "Exercices affichés")?.value).toBe("2024, 2025");
    expect(meta.rows[0][0]).toBe("2024");
    expect(meta.rows[1][0]).toBe("2025");
  });

  it("expose le tri et la direction courants", () => {
    const meta = buildPdfMeta({
      userEmail: "u@x",
      timestamp: "t",
      rows,
      sortKey: "resultat",
      sortDir: "asc",
      showPct: false,
    });
    expect(meta.summary.find((s) => s.label === "Tri")?.value).toBe("Résultat (croissant)");
  });

  it("ajoute la colonne % évolution quand showPct=true", () => {
    const meta = buildPdfMeta({
      userEmail: "u@x",
      timestamp: "t",
      rows,
      sortKey: "code",
      sortDir: "asc",
      showPct: true,
    });
    expect(meta.headers).toContain("% évolution CA");
    expect(meta.rows[0]).toHaveLength(meta.headers.length);
    // premier: pas de comparatif, dernier caractère == "—"
    expect(meta.rows[0][meta.rows[0].length - 1]).toBe("—");
    // 2025 vs 2024: +50 %
    expect(String(meta.rows[1][meta.rows[1].length - 1])).toContain("50.0");
    expect(meta.summary.find((s) => s.label === "% évolution")?.value).toBe("Inclus");
  });

  it("masque la colonne % quand showPct=false", () => {
    const meta = buildPdfMeta({
      userEmail: "u@x",
      timestamp: "t",
      rows,
      sortKey: "code",
      sortDir: "asc",
      showPct: false,
    });
    expect(meta.headers).not.toContain("% évolution CA");
    expect(meta.summary.find((s) => s.label === "% évolution")?.value).toBe("Masqués");
  });

  it("garantit la parité contenu/écran (mêmes lignes, même ordre)", () => {
    const reordered = [...rows].reverse();
    const meta = buildPdfMeta({
      userEmail: "u@x",
      timestamp: "t",
      rows: reordered,
      sortKey: "ca",
      sortDir: "asc",
      showPct: false,
    });
    expect(meta.rows.map((r) => r[0])).toEqual(["2025", "2024"]);
    expect(meta.summary.find((s) => s.label === "Exercices affichés")?.value).toBe("2025, 2024");
  });
});
