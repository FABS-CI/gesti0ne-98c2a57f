import { describe, it, expect } from "vitest";
import { fmtMontant } from "./tourneePdf";

describe("fmtMontant", () => {
  it("formate les milliers avec espace ASCII", () => {
    expect(fmtMontant(15000)).toBe("15 000");
    expect(fmtMontant(4000)).toBe("4 000");
    expect(fmtMontant(28000)).toBe("28 000");
  });

  it("formate les millions avec deux espaces", () => {
    expect(fmtMontant(1500000)).toBe("1 500 000");
  });

  it("arrondit les décimales", () => {
    expect(fmtMontant(15000.4)).toBe("15 000");
    expect(fmtMontant(15000.6)).toBe("15 001");
  });

  it("gère zéro et petits nombres", () => {
    expect(fmtMontant(0)).toBe("0");
    expect(fmtMontant(42)).toBe("42");
    expect(fmtMontant(999)).toBe("999");
  });

  it("gère les montants négatifs", () => {
    expect(fmtMontant(-15000)).toBe("-15 000");
  });

  it("ne contient jamais de narrow no-break space (\\u202f) ni de nbsp (\\u00a0)", () => {
    const samples = [1000, 15000, 1500000, 9999999];
    for (const s of samples) {
      const out = fmtMontant(s);
      expect(out).not.toMatch(/[\u00a0\u202f]/);
      // Seuls espaces ASCII et chiffres (et signe -) sont autorisés
      expect(out).toMatch(/^-?[0-9 ]+$/);
    }
  });

  it("produit un rendu cohérent « 15 000 » réutilisable avec suffixe FCFA", () => {
    expect(`${fmtMontant(15000)} FCFA`).toBe("15 000 FCFA");
  });
});