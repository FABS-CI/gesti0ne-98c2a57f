import { describe, expect, it } from "vitest";
import { retourFormSchema } from "./retours-form";

const uuid = "11111111-1111-4111-8111-111111111111";
const uuid2 = "22222222-2222-4222-8222-222222222222";

const base = {
  date_retour: "2026-01-15",
  client_id: uuid,
  type_retour: "physique" as const,
  etablissement: "ACME",
  representant_nom: "",
  telephone: "",
  ville: "",
  adresse: "",
  observations: "",
  depot_id: uuid,
  lignes: [{ produit_id: uuid, designation: "Produit A", quantite: 2 }],
};

describe("retourFormSchema", () => {
  it("accepte un retour libre valide", () => {
    const r = retourFormSchema.safeParse(base);
    expect(r.success).toBe(true);
  });

  it("refuse un client_id vide", () => {
    const r = retourFormSchema.safeParse({ ...base, client_id: "" });
    expect(r.success).toBe(false);
  });

  it("refuse quantité < 1", () => {
    const r = retourFormSchema.safeParse({
      ...base,
      lignes: [{ produit_id: uuid, designation: "A", quantite: 0 }],
    });
    expect(r.success).toBe(false);
  });

  it("refuse deux lignes avec le même produit", () => {
    const r = retourFormSchema.safeParse({
      ...base,
      lignes: [
        { produit_id: uuid, designation: "A", quantite: 1 },
        { produit_id: uuid, designation: "A", quantite: 1 },
      ],
    });
    expect(r.success).toBe(false);
    if (!r.success) {
      expect(r.error.issues.some((i) => /déjà présent/.test(i.message))).toBe(true);
    }
  });

  it("refuse une quantité supérieure au disponible (facture rattachée)", () => {
    const r = retourFormSchema.safeParse({
      ...base,
      facture_id: uuid2,
      lignes: [
        {
          produit_id: uuid,
          designation: "A",
          quantite: 10,
          qte_disponible: 3,
          prix_unitaire: 1000,
        },
      ],
    });
    expect(r.success).toBe(false);
    if (!r.success) {
      expect(r.error.issues.some((i) => /disponible/.test(i.message))).toBe(true);
    }
  });

  it("accepte quantité <= disponible", () => {
    const r = retourFormSchema.safeParse({
      ...base,
      facture_id: uuid2,
      lignes: [
        {
          produit_id: uuid,
          designation: "A",
          quantite: 3,
          qte_disponible: 3,
          prix_unitaire: 1000,
        },
      ],
    });
    expect(r.success).toBe(true);
  });

  it("refuse un facture_id qui n'est pas un UUID", () => {
    const r = retourFormSchema.safeParse({ ...base, facture_id: "abc" });
    expect(r.success).toBe(false);
  });
});
