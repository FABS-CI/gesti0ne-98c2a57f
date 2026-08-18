import { render } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";
import { EtiquetteCarton, type EtiquettePayload } from "./EtiquetteCarton";

vi.mock("qrcode", () => ({
  default: { toDataURL: () => Promise.resolve("data:image/png;base64,") },
}));

function makeData(numero: number, nb: number): EtiquettePayload {
  return {
    commande: "CMD-001",
    bl: "BL-TEST",
    colis_id: `colis-${numero}`,
    client: "Client X",
    telephone: "0700000000",
    ville: "Abidjan",
    nb_cartons: nb,
    numero_carton: numero,
    mode_acheminement: "livraison",
    produits: [{ nom: "Cahier", designation: "Cahier", quantite: 10 }],
  };
}

describe("EtiquetteCarton", () => {
  it("expose data-colis-id et pagination N/total identique par carton", () => {
    const total = 3;
    for (let i = 1; i <= total; i++) {
      const { container } = render(<EtiquetteCarton data={makeData(i, total)} />);
      const root = container.querySelector(".etiquette-carton");
      expect(root).not.toBeNull();
      expect(root?.getAttribute("data-colis-id")).toBe(`colis-${i}`);
      expect(root?.textContent).toContain(`${i} / ${total}`);
      expect(root?.textContent).toContain("BL-TEST");
    }
  });
});
