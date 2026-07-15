import type { ColisInfo, LivSuiviCommande } from "./types";

export type SuiviDefaults = {
  livreur_nom: string | null;
  vehicule: string | null;
  gare_destination: string | null;
  ville_destination: string | null;
  receptionnaire_nom: string | null;
};

/**
 * Chaîne de repli pour préremplir l'écran d'avancement d'étape :
 * suivi -> tournée -> colisage -> commande.
 */
export function computeSuiviDefaults(
  suivi: LivSuiviCommande & { colis?: ColisInfo | null },
): SuiviDefaults {
  const colis = suivi.colis ?? null;
  return {
    livreur_nom:
      suivi.livreur_nom ??
      suivi.tournee?.livreur_nom ??
      colis?.livreur_nom ??
      colis?.transporteur ??
      null,
    vehicule: suivi.vehicule ?? suivi.tournee?.vehicule ?? colis?.vehicule ?? null,
    gare_destination: suivi.gare_destination ?? colis?.gare_depart ?? null,
    ville_destination:
      suivi.ville_destination ?? colis?.ville_destination ?? colis?.ville_livraison ?? null,
    receptionnaire_nom:
      suivi.receptionnaire_nom ?? colis?.destinataire ?? suivi.commande?.client_nom ?? null,
  };
}