import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock du client Supabase avant l'import du module testé
type CountResp = { count: number | null; error: null };
type InsertResp = { data: { livraison_id: string } | null; error: unknown };

const counts: Record<string, number> = {};
const insertMock = vi.fn(async (): Promise<InsertResp> => ({ data: null, error: null }));

function makeCountChain(table: string): { count: number | null; error: null } {
  return { count: counts[table] ?? 0, error: null };
}

vi.mock("@/integrations/supabase/client", () => {
  const from = (table: string) => ({
    select: (_cols: string, opts?: { head?: boolean; count?: string }) => {
      if (opts?.head) {
        // renvoie un thenable pour supporter .eq(...).then(cb)
        const eqChain = {
          eq: (_c: string, _v: string) => Promise.resolve(makeCountChain(table) as CountResp),
        };
        return eqChain;
      }
      // insert().select().single()
      return {
        single: () => insertMock(),
      };
    },
    insert: (_row: unknown) => ({
      select: (_cols: string) => ({
        single: () => insertMock(),
      }),
    }),
  });
  return { supabase: { from } };
});

import { createLivraison, type CreateLivraisonInput } from "./livraisons-api";

const baseInput: CreateLivraisonInput = {
  bl_id: null,
  expedition_id: null,
  client_id: "c1",
  transporteur_id: "t1",
  livreur_id: "l1",
  gare_depart_id: "g1",
  gare_arrivee_id: "g2",
  date_livraison: "2026-07-06",
  adresse: "Abidjan",
  ville: "Abidjan",
  commune: "Adjamé",
  telephone_dest: null,
  contact_dest: null,
  notes: null,
  client_nom: "Client",
  transporteur_nom: "UTB",
};

describe("createLivraison — validation d'existence", () => {
  beforeEach(() => {
    Object.keys(counts).forEach((k) => delete counts[k]);
    insertMock.mockReset();
    insertMock.mockResolvedValue({
      data: { livraison_id: "new-id" },
      error: null,
    });
  });

  it("crée la livraison quand tout existe", async () => {
    counts.transporteurs = 1;
    counts.livreurs = 1;
    counts.gares = 1;
    const res = await createLivraison(baseInput);
    expect(res.livraison_id).toBe("new-id");
    expect(insertMock).toHaveBeenCalledTimes(1);
  });

  it("refuse un transporteur inexistant", async () => {
    counts.transporteurs = 0;
    counts.livreurs = 1;
    counts.gares = 1;
    await expect(createLivraison(baseInput)).rejects.toThrow(/Transporteur/);
    expect(insertMock).not.toHaveBeenCalled();
  });

  it("refuse un livreur inexistant", async () => {
    counts.transporteurs = 1;
    counts.livreurs = 0;
    counts.gares = 1;
    await expect(createLivraison(baseInput)).rejects.toThrow(/Livreur/);
    expect(insertMock).not.toHaveBeenCalled();
  });

  it("refuse une gare inexistante", async () => {
    counts.transporteurs = 1;
    counts.livreurs = 1;
    counts.gares = 0;
    await expect(createLivraison(baseInput)).rejects.toThrow(/Gare/);
    expect(insertMock).not.toHaveBeenCalled();
  });

  it("cumule les libellés dans l'erreur", async () => {
    counts.transporteurs = 0;
    counts.livreurs = 0;
    counts.gares = 0;
    await expect(createLivraison(baseInput)).rejects.toThrow(/Transporteur.*Livreur/);
  });
});
