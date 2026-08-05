import type { LivStatut, LivType } from "./types";

export const STATUT_LABEL: Record<LivStatut, string> = {
  preparee: "Préparée",
  chargee: "Chargée dans camion",
  en_route: "En route",
  remise_livreur: "Remise au livreur",
  depart_depot: "Départ du dépôt",
  arrive_client: "Arrivé chez le client",
  livree: "Livrée",
  reception_confirmee: "Réception confirmée",
  non_livre: "Non livrée",
  remise_transporteur: "Remise au transporteur",
  expediee: "Expédiée",
  arrivee_gare: "Arrivée à la gare",
  retiree_client: "Retirée par le client",
  livree_locale: "Livrée localement",
};

export const STATUT_COLOR: Record<LivStatut, string> = {
  preparee: "#10B981",
  chargee: "#0EA5E9",
  en_route: "#3B82F6",
  remise_livreur: "#3B82F6",
  depart_depot: "#3B82F6",
  arrive_client: "#F59E0B",
  livree: "#059669",
  reception_confirmee: "#047857",
  non_livre: "#DC2626",
  remise_transporteur: "#3B82F6",
  expediee: "#3B82F6",
  arrivee_gare: "#F59E0B",
  retiree_client: "#059669",
  livree_locale: "#059669",
};

export function workflowSteps(type: LivType): LivStatut[] {
  return type === "direct"
    ? ["preparee", "chargee", "remise_livreur", "depart_depot", "en_route", "arrive_client", "livree", "reception_confirmee"]
    : ["preparee", "chargee", "remise_transporteur", "expediee", "arrivee_gare", "retiree_client", "reception_confirmee"];
}

export function nextEtape(type: LivType, statut: LivStatut): LivStatut | null {
  const steps = workflowSteps(type);
  const i = steps.indexOf(statut);
  if (i < 0 || i >= steps.length - 1) return null;
  return steps[i + 1];
}

/** Champs supplémentaires demandés à la validation d'une étape. */
export function etapeInputs(
  etape: LivStatut,
): Array<{ key: string; label: string; required?: boolean }> {
  switch (etape) {
    case "remise_livreur":
      return [
        { key: "livreur_nom", label: "Nom du livreur", required: true },
        { key: "vehicule", label: "Véhicule (optionnel)" },
      ];
    case "remise_transporteur":
      return [
        { key: "livreur_nom", label: "Transporteur / agent", required: true },
        { key: "vehicule", label: "Véhicule / n° BSC (optionnel)" },
      ];
    case "arrivee_gare":
      return [
        { key: "gare_destination", label: "Nom de la gare", required: true },
        { key: "ville_destination", label: "Ville", required: true },
      ];
    case "livree":
    case "retiree_client":
    case "livree_locale":
      return [{ key: "receptionnaire_nom", label: "Réceptionnaire (optionnel)" }];
    default:
      return [];
  }
}
