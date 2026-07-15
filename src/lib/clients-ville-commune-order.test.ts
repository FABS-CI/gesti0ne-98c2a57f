import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

function read(p: string) {
  return readFileSync(resolve(process.cwd(), p), "utf8");
}

describe("Ville avant Commune", () => {
  it("dans le panneau d'édition client", () => {
    const src = read("src/components/clients/ClientEditSheet.tsx");
    const iVille = src.indexOf('label="Ville"');
    const iCommune = src.indexOf('label="Commune"');
    expect(iVille).toBeGreaterThan(-1);
    expect(iCommune).toBeGreaterThan(-1);
    expect(iVille).toBeLessThan(iCommune);
  });

  it("dans la fiche client (lecture seule)", () => {
    const src = read("src/components/clients/detail/ClientInfosTab.tsx");
    const iVille = src.indexOf('label="Ville"');
    const iCommune = src.indexOf('label="Commune"');
    expect(iVille).toBeGreaterThan(-1);
    expect(iCommune).toBeGreaterThan(-1);
    expect(iVille).toBeLessThan(iCommune);
  });
});
