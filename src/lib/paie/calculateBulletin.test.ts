import { describe, it, expect } from "vitest";
import { calculateBulletin, PLAFOND_CNPS, TAUX } from "./calculateBulletin";

describe("calculateBulletin", () => {
  it("renvoie tout à 0 pour un salaire nul", () => {
    const r = calculateBulletin({ salaireBase: 0 });
    expect(r.salaireBrut).toBe(0);
    expect(r.salaireNet).toBe(0);
    expect(r.montantIR).toBe(0);
    expect(r.chargesTotalesEmployeur).toBe(0);
  });

  it("traite les montants négatifs comme 0 (jamais de brut négatif)", () => {
    const r = calculateBulletin({ salaireBase: -500_000, primes: -1000, heuresSup: -1 });
    expect(r.salaireBrut).toBe(0);
    expect(r.salaireNet).toBe(0);
    expect(r.baseIR).toBe(0);
  });

  it("arrondit toutes les cotisations à l'entier", () => {
    const r = calculateBulletin({ salaireBase: 333_333, primes: 7 });
    for (const v of [
      r.cotisationCNPSSalarie,
      r.cotisationCNPSEmployeur,
      r.prestationsFamiliales,
      r.accidentTravail,
      r.formationPro,
      r.baseIR,
      r.montantIR,
    ]) {
      expect(Number.isInteger(v)).toBe(true);
    }
  });

  it("plafonne la base CNPS au plafond légal", () => {
    const r = calculateBulletin({ salaireBase: PLAFOND_CNPS * 3 });
    expect(r.cotisationCNPSSalarie).toBe(Math.round(PLAFOND_CNPS * TAUX.cnpsSalarie));
    expect(r.cotisationCNPSEmployeur).toBe(Math.round(PLAFOND_CNPS * TAUX.cnpsEmployeurRetraite));
  });

  it("respecte l'identité coût employeur = brut + charges patronales", () => {
    const r = calculateBulletin({ salaireBase: 450_000, primes: 25_000 });
    expect(r.coutTotalEmployeur).toBe(r.salaireBrut + r.chargesTotalesEmployeur);
  });

  it("respecte l'identité net = brut − CNPS salarié − IR", () => {
    const r = calculateBulletin({ salaireBase: 600_000 });
    expect(r.salaireNet).toBe(r.salaireBrut - r.cotisationCNPSSalarie - r.montantIR);
  });

  it("l'IR est nul sous le premier seuil (75 000 base imposable)", () => {
    const r = calculateBulletin({ salaireBase: 60_000 });
    expect(r.montantIR).toBe(0);
  });
});
