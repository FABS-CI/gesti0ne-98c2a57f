import { describe, expect, it } from "vitest";

import { getRoutePermission } from "@/lib/route-permissions";

describe("route permission mapping", () => {
  it("uses action permissions for commercial create/edit routes instead of list permissions", () => {
    expect(getRoutePermission("/clients/nouveau")).toBe("clients.creer");
    expect(getRoutePermission("/clients/abc/modifier")).toBe("clients.modifier");
    expect(getRoutePermission("/commandes/nouvelle")).toBe("commandes.creer");
    expect(getRoutePermission("/paiements/nouveau")).toBe("paiements.creer");
  });

  it("maps logistics submodules to their own permissions", () => {
    expect(getRoutePermission("/clients/dashboard")).toBe("clients_dashboard.voir");
    expect(getRoutePermission("/colisage/responsables")).toBe("colisage_responsables.voir");
    expect(getRoutePermission("/livraison-suivi")).toBe("livraison_suivi.voir");
    expect(getRoutePermission("/stock/audit")).toBe("stock.voir_audit");
    expect(getRoutePermission("/alertes-stock")).toBe("alertes_stock.voir");
    expect(getRoutePermission("/livreurs")).toBe("livreurs.voir");
    expect(getRoutePermission("/dashboard-logistique")).toBe("dashboard_logistique.voir");
    expect(getRoutePermission("/rapports-logistique")).toBe("rapports_logistique.voir");
  });

  it("keeps dynamic detail routes on view permissions", () => {
    expect(getRoutePermission("/produits/123")).toBe("produits.voir");
    expect(getRoutePermission("/transferts/123")).toBe("transferts.voir");
    expect(getRoutePermission("/inventaires/123")).toBe("inventaires.voir");
  });
});