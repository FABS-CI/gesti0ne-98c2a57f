import { describe, it, expect } from "vitest";
import {
  validateMontantPaiement,
  arrondirFCFA,
  ecritureEquilibree,
  isDoublonPaiement,
  periodesChevauchent,
  indexPremierChevauchement,
} from "./finance-validators";

describe("validateMontantPaiement", () => {
  it("refuse un montant négatif", () => {
    expect(validateMontantPaiement(-1000)).toEqual({
      ok: false,
      error: expect.stringContaining("positif"),
    });
  });
  it("refuse un montant nul", () => {
    expect(validateMontantPaiement(0).ok).toBe(false);
  });
  it("refuse NaN / infini / chaîne non numérique", () => {
    expect(validateMontantPaiement(NaN).ok).toBe(false);
    expect(validateMontantPaiement(Infinity).ok).toBe(false);
    expect(validateMontantPaiement("abc").ok).toBe(false);
  });
  it("accepte et arrondit à l'entier", () => {
    expect(validateMontantPaiement(1234.6)).toEqual({ ok: true, montant: 1235 });
    expect(validateMontantPaiement("1000")).toEqual({ ok: true, montant: 1000 });
  });
});

describe("arrondirFCFA", () => {
  it("arrondit au plus proche entier", () => {
    expect(arrondirFCFA(1.4)).toBe(1);
    expect(arrondirFCFA(1.5)).toBe(2);
    expect(arrondirFCFA(-1.5)).toBe(-1); // Math.round: banker's? non, JS: half-away-from-zero pour positifs
  });
});

describe("ecritureEquilibree", () => {
  it("valide une écriture équilibrée", () => {
    expect(ecritureEquilibree([{ debit: 1000 }, { credit: 400 }, { credit: 600 }])).toBe(true);
  });
  it("rejette une écriture déséquilibrée", () => {
    expect(ecritureEquilibree([{ debit: 1000 }, { credit: 400 }])).toBe(false);
  });
  it("ignore les null / undefined", () => {
    expect(
      ecritureEquilibree([
        { debit: 500, credit: null },
        { debit: null, credit: 500 },
      ]),
    ).toBe(true);
  });
});

describe("isDoublonPaiement", () => {
  const base = {
    facture_id: "F1",
    montant: 10_000,
    date_paiement: "2026-01-05",
    mode_paiement: "especes",
  };
  it("détecte un doublon exact", () => {
    expect(isDoublonPaiement(base, { ...base })).toBe(true);
  });
  it("ne considère pas comme doublon si mode diffère", () => {
    expect(isDoublonPaiement(base, { ...base, mode_paiement: "cheque" })).toBe(false);
  });
  it("ne considère pas comme doublon sans facture", () => {
    expect(isDoublonPaiement({ ...base, facture_id: null }, { ...base, facture_id: null })).toBe(
      false,
    );
  });
  it("tolère un écart de centime (arrondi FCFA)", () => {
    expect(isDoublonPaiement(base, { ...base, montant: 10_000.4 })).toBe(true);
  });
});

describe("periodesChevauchent / indexPremierChevauchement", () => {
  it("détecte le chevauchement de bornes incluses", () => {
    expect(
      periodesChevauchent(
        { debut: "2026-01-01", fin: "2026-01-31" },
        {
          debut: "2026-01-31",
          fin: "2026-02-28",
        },
      ),
    ).toBe(true);
  });
  it("rejette deux périodes disjointes", () => {
    expect(
      periodesChevauchent(
        { debut: "2026-01-01", fin: "2026-01-31" },
        {
          debut: "2026-02-01",
          fin: "2026-02-28",
        },
      ),
    ).toBe(false);
  });
  it("indexPremierChevauchement renvoie -1 si aucune", () => {
    expect(
      indexPremierChevauchement([
        { debut: "2026-01-01", fin: "2026-01-31" },
        { debut: "2026-02-01", fin: "2026-02-28" },
      ]),
    ).toBe(-1);
  });
  it("indexPremierChevauchement pointe la première paire en conflit", () => {
    expect(
      indexPremierChevauchement([
        { debut: "2026-01-01", fin: "2026-01-31" },
        { debut: "2026-03-01", fin: "2026-03-31" },
        { debut: "2026-01-15", fin: "2026-02-15" },
      ]),
    ).toBe(0);
  });
});
