import { describe, it, expect } from "vitest";
import { isValidateDisabled, formatAdresseLivraison } from "./livraison-suivi.$commandeRef.remise";

const base = {
  isPending: false,
  canValidate: true,
  isError: false,
  isSuccess: false,
  hasData: false,
};

describe("isValidateDisabled — bouton « Valider l'étape »", () => {
  it("est actif quand tout est prêt et aucune tentative n'a été faite", () => {
    expect(isValidateDisabled(base)).toBe(false);
  });

  it("est désactivé pendant la mutation", () => {
    expect(isValidateDisabled({ ...base, isPending: true })).toBe(true);
  });

  it("est désactivé si des données requises manquent", () => {
    expect(isValidateDisabled({ ...base, canValidate: false })).toBe(true);
  });

  it("reste désactivé après une erreur API jusqu'au rechargement", () => {
    expect(isValidateDisabled({ ...base, isError: true })).toBe(true);
  });

  it("reste désactivé quand la RPC répond « 0 mise à jour » (success sans data)", () => {
    expect(isValidateDisabled({ ...base, isSuccess: true, hasData: false })).toBe(true);
  });

  it("n'est pas bloqué par un succès qui a bien renvoyé des données", () => {
    // (En pratique on navigue ailleurs, mais la logique locale doit rester cohérente.)
    expect(isValidateDisabled({ ...base, isSuccess: true, hasData: true })).toBe(false);
  });
});

describe("formatAdresseLivraison — fallback quand adresse manquante", () => {
  it("retourne l'adresse quand elle est renseignée", () => {
    expect(formatAdresseLivraison({ adresse: "12 rue X", ville: "Abidjan" })).toBe("12 rue X");
  });

  it("retombe sur la ville si adresse est null / vide", () => {
    expect(formatAdresseLivraison({ adresse: null, ville: "Abidjan" })).toBe("Abidjan");
    expect(formatAdresseLivraison({ adresse: "   ", ville: "Abidjan" })).toBe("Abidjan");
  });

  it("retourne un tiret si aucun des deux champs n'est fourni (pas de crash)", () => {
    expect(formatAdresseLivraison({})).toBe("—");
    expect(formatAdresseLivraison(null)).toBe("—");
    expect(formatAdresseLivraison(undefined)).toBe("—");
  });
});
