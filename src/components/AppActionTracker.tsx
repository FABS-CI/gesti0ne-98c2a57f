import { useEffect, useRef } from "react";
import { useRouterState } from "@tanstack/react-router";
import { useTrackAction } from "@/hooks/use-track-action";
import { MODULE_META } from "@/lib/shortcuts-catalog";

/**
 * Global listener that maps the current URL to a trackable action.
 * - Creation routes (…/nouveau, …/nouvelle, …/nouveau-physique) → `<segment>.create`
 * - Any authenticated route → `<module>.visit` (top-level segment)
 */
const CREATE_MAP: Record<string, string> = {
  commandes: "commandes.create",
  clients: "clients.create",
  paiements: "paiements.create",
  factures: "factures.create",
  proformas: "devis.create",
  livraisons: "livraisons.create",
  colisage: "colisage.create",
  achats: "reception.create",
  produits: "articles.create",
  tournees: "tournees.create",
};

const MODULE_MAP: Record<string, string> = {
  commandes: "commercial",
  proformas: "commercial",
  clients: "crm",
  paiements: "finance",
  factures: "finance",
  comptabilite: "finance",
  balance: "finance",
  produits: "stock",
  depots: "stock",
  "alertes-stock": "stock",
  achats: "stock",
  livraisons: "logistique",
  colisage: "logistique",
  tournees: "logistique",
  "bons-livraison": "logistique",
  employes: "rh",
  contrats: "rh",
  conges: "rh",
  absences: "rh",
  paie: "rh",
  vehicules: "flotte",
  missions: "flotte",
};

export function AppActionTracker() {
  const track = useTrackAction();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const lastRef = useRef<string>("");

  useEffect(() => {
    if (!path || path === lastRef.current) return;
    lastRef.current = path;
    const segs = path.split("/").filter(Boolean);
    if (segs.length === 0) return;
    const top = segs[0];

    // Creation route tracking
    const last = segs[segs.length - 1];
    if (last.startsWith("nouveau") || last.startsWith("nouvelle")) {
      const key = CREATE_MAP[top];
      if (key) track(key);
    }

    // Module visit tracking (throttled naturally by pathname change)
    const module = MODULE_MAP[top];
    if (module) {
      track(`${top}.visit`, {
        module,
        label: MODULE_META[module]?.label ?? top,
        icon: "",
        href: `/${top}`,
      });
    }
  }, [path, track]);

  return null;
}
