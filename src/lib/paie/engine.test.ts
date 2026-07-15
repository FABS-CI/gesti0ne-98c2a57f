import { describe, it, expect } from "vitest";
import { runEngine } from "./engine";

describe("runEngine (paie CI paramétrable)", () => {
  it("gère un salaire nul (aucune ligne négative)", () => {
    const r = runEngine({ salaireBase: 0 }, [], []);
    expect(r.salaireBrut).toBe(0);
    expect(r.salaireNet).toBeGreaterThanOrEqual(-r.cmuSalarie - 1); // CMU fixe déduite
    for (const l of r.lignes) {
      expect(l.gain).toBeGreaterThanOrEqual(0);
      expect(l.retenue).toBeGreaterThanOrEqual(0);
      expect(l.patronale).toBeGreaterThanOrEqual(0);
    }
  });

  it("traite les montants négatifs comme 0", () => {
    const r = runEngine({ salaireBase: -100_000, primes: -50, heuresSup: -1 }, [], []);
    expect(r.salaireBrut).toBe(0);
    expect(r.totalGains).toBe(0);
  });

  it("identités comptables: totalGains = brut, net = brut − retenues, coût = brut + patronales", () => {
    const r = runEngine({ salaireBase: 500_000, primes: 25_000 }, [], []);
    expect(r.totalGains).toBe(r.salaireBrut);
    expect(r.salaireNet).toBe(r.salaireBrut - r.totalRetenues);
    expect(r.coutEmployeur).toBe(r.salaireBrut + r.totalPatronales);
  });

  it("toutes les lignes ont des montants entiers (arrondis)", () => {
    const r = runEngine({ salaireBase: 333_333, primes: 12_345 }, [], []);
    for (const l of r.lignes) {
      expect(Number.isInteger(l.gain)).toBe(true);
      expect(Number.isInteger(l.retenue)).toBe(true);
      expect(Number.isInteger(l.patronale)).toBe(true);
    }
  });

  it("applique les rubriques custom (gain et retenue)", () => {
    const r = runEngine(
      {
        salaireBase: 400_000,
        rubriquesCustom: [
          { code: "PRIME_ANC", libelle: "Ancienneté", type: "gain", montant: 20_000 },
          { code: "AVANCE", libelle: "Avance sur salaire", type: "retenue", montant: 30_000 },
        ],
      },
      [],
      [],
    );
    expect(r.salaireBrut).toBe(420_000);
    expect(r.lignes.some((l) => l.code === "AVANCE" && l.retenue === 30_000)).toBe(true);
  });
});
