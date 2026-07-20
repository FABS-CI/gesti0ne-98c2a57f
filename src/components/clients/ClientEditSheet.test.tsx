import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ClientEditSheet } from "./ClientEditSheet";
import type { Client } from "@/lib/clients-api";

const client: Client = {
  client_id: "c1",
  reference: "CLI-1",
  nom: "Test",
  type_client: "librairie",
  representant: null,
  telephone: null,
  email: null,
  adresse: null,
  ville: "Abidjan",
  commune: "Cocody",
  quartier: null,
  bp: null,
  pays: "Côte d'Ivoire",

  nif: null,
  regime_fiscal: null,
  categorie: null,
  secteur_activite: null,
  mode_paiement: "comptant",
  delai_paiement: 0,
  remise_habituelle: 0,
  plafond_credit: 0,
  solde: 0,
  notes: null,
  statut: "actif",
  motif_blocage: null,
  actif: true,
  created_at: "",
  updated_at: "",
};

function renderSheet() {
  const qc = new QueryClient();
  return render(
    <QueryClientProvider client={qc}>
      <ClientEditSheet client={client} open onOpenChange={() => {}} />
    </QueryClientProvider>,
  );
}

describe("ClientEditSheet — Ville / Commune", () => {
  it("affiche Ville avant Commune", () => {
    renderSheet();
    const ville = screen.getByText("Ville");
    const commune = screen.getByText("Commune");
    // compareDocumentPosition FOLLOWING = 4
    expect(ville.compareDocumentPosition(commune) & 4).toBeTruthy();
  });

  it("place Ville et Commune côte à côte dans une grille 2 colonnes (>= sm)", () => {
    const { container } = renderSheet();
    const villeField = screen.getByText("Ville").closest("div");
    const communeField = screen.getByText("Commune").closest("div");
    expect(villeField?.parentElement).toBe(communeField?.parentElement);
    const grid = villeField?.parentElement;
    const classes = (grid?.className ?? "").split(/\s+/);
    // mobile par défaut = 1 colonne (aucune classe grid-cols-* sans variante), desktop >= sm = 2 colonnes
    expect(classes).toContain("grid");
    expect(classes.some((c) => /^grid-cols-\d/.test(c))).toBe(false);
    expect(classes).toContain("sm:grid-cols-2");
    // ordre DOM préservé pour toutes les tailles (le CSS suit l'ordre source)
    const children = Array.from(grid!.children);
    expect(children.indexOf(villeField!)).toBeLessThan(children.indexOf(communeField!));
    expect(container).toBeTruthy();
  });

  it("associe les labels Ville et Commune à leur champ (a11y)", () => {
    renderSheet();
    const villeInput = screen.getByLabelText("Ville") as HTMLInputElement;
    const communeInput = screen.getByLabelText("Commune") as HTMLInputElement;
    expect(villeInput).toBeInTheDocument();
    expect(communeInput).toBeInTheDocument();
    expect(villeInput.value).toBe("Abidjan");
    expect(communeInput.value).toBe("Cocody");
  });
});
