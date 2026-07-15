import { describe, it, expect } from "vitest";
import { computeSuiviDefaults } from "./defaults";
import type { LivSuiviCommande, ColisInfo } from "./types";

function make(
  suivi: Partial<LivSuiviCommande> = {},
  colis: Partial<ColisInfo> | null = null,
): LivSuiviCommande & { colis: ColisInfo | null } {
  return {
    id: "s1",
    commande_id: "c1",
    tournee_id: null,
    type_livraison: "direct",
    gare_depot: null,
    gare_destination: null,
    ville_destination: null,
    livreur_nom: null,
    vehicule: null,
    receptionnaire_nom: null,
    statut: "preparee",
    derniere_maj: "",
    cloturee: false,
    created_at: "",
    updated_at: "",
    ...suivi,
    colis: colis
      ? ({
          reference: null,
          numero_carton: null,
          nb_cartons: null,
          contenu: null,
          destinataire: null,
          transporteur: null,
          date_envoi: null,
          poids: null,
          bl_reference: null,
          bl_date_livraison: null,
          depot_nom: null,
          nb_colis: 0,
          livreur_nom: null,
          livreur_telephone: null,
          vehicule: null,
          gare_depart: null,
          gare_responsable: null,
          gare_telephone: null,
          ville_destination: null,
          ville_livraison: null,
          quartier: null,
          commune: null,
          mode_acheminement: null,
          ...colis,
        } as ColisInfo)
      : null,
  };
}

describe("computeSuiviDefaults — chaîne de repli", () => {
  it("prend le suivi en priorité", () => {
    const d = computeSuiviDefaults(
      make({ livreur_nom: "Suivi", vehicule: "SV" }, { livreur_nom: "Colis", vehicule: "CV" }),
    );
    expect(d.livreur_nom).toBe("Suivi");
    expect(d.vehicule).toBe("SV");
  });

  it("repli tournée puis colis puis transporteur", () => {
    const d1 = computeSuiviDefaults(
      make(
        { tournee: { livreur_nom: "Tour", vehicule: "TV" } as never },
        { livreur_nom: "Colis", vehicule: "CV" },
      ),
    );
    expect(d1.livreur_nom).toBe("Tour");
    expect(d1.vehicule).toBe("TV");

    const d2 = computeSuiviDefaults(make({}, { livreur_nom: "Colis", vehicule: "CV" }));
    expect(d2.livreur_nom).toBe("Colis");
    expect(d2.vehicule).toBe("CV");

    const d3 = computeSuiviDefaults(make({}, { transporteur: "TRP" }));
    expect(d3.livreur_nom).toBe("TRP");
  });

  it("ville et gare de destination utilisent le colisage en repli", () => {
    const d = computeSuiviDefaults(
      make({}, { gare_depart: "Abj", ville_destination: null, ville_livraison: "Bouake" }),
    );
    expect(d.gare_destination).toBe("Abj");
    expect(d.ville_destination).toBe("Bouake");
  });

  it("réceptionnaire : destinataire colis puis client commande", () => {
    const d1 = computeSuiviDefaults(make({}, { destinataire: "Dest" }));
    expect(d1.receptionnaire_nom).toBe("Dest");
    const d2 = computeSuiviDefaults(
      make({ commande: { reference: "R", client_nom: "Cli" } as never }),
    );
    expect(d2.receptionnaire_nom).toBe("Cli");
  });

  it("null quand rien nulle part", () => {
    const d = computeSuiviDefaults(make());
    expect(d).toEqual({
      livreur_nom: null,
      vehicule: null,
      gare_destination: null,
      ville_destination: null,
      receptionnaire_nom: null,
    });
  });
});