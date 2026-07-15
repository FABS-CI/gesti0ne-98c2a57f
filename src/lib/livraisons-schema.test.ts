import { describe, it, expect } from "vitest";
import { livraisonFormSchema } from "./livraisons-schema";

const UUID = "f47ac10b-58cc-4372-a567-0e02b2c3d479";
const UUID2 = "550e8400-e29b-41d4-a716-446655440000";
const UUID3 = "6ba7b810-9dad-41d1-80b4-00c04fd430c8";
const UUID4 = "6ba7b811-9dad-41d1-80b4-00c04fd430c8";

const base = {
  source_type: "colisage" as const,
  source_id: UUID,
  transporteur_id: UUID,
  livreur_id: UUID2,
  gare_depart_id: null,
  gare_arrivee_id: null,
  date_livraison: "2026-07-06",
  notes: null,
};

describe("livraisonFormSchema", () => {
  it("accepte une entrée entièrement valide", () => {
    const r = livraisonFormSchema.safeParse(base);
    expect(r.success).toBe(true);
  });

  it.each([
    ["transporteur_id", "UTB Adjamé"],
    ["transporteur_id", ""],
    ["livreur_id", "Kouassi"],
    ["source_id", "BL-2026-001"],
    ["gare_depart_id", "Adjamé Gbêba"],
    ["gare_arrivee_id", "Bouaké"],
  ])("rejette une saisie libre dans %s (%s)", (field, val) => {
    const r = livraisonFormSchema.safeParse({ ...base, [field]: val });
    expect(r.success).toBe(false);
  });

  it("rejette une date vide", () => {
    const r = livraisonFormSchema.safeParse({ ...base, date_livraison: "" });
    expect(r.success).toBe(false);
  });

  it("accepte gare_depart_id/gare_arrivee_id renseignés", () => {
    const r = livraisonFormSchema.safeParse({
      ...base,
      gare_depart_id: UUID3,
      gare_arrivee_id: UUID4,
    });
    expect(r.success).toBe(true);
  });

  it("rejette un UUID mal formé", () => {
    const r = livraisonFormSchema.safeParse({ ...base, transporteur_id: "not-a-uuid" });
    expect(r.success).toBe(false);
  });
});
