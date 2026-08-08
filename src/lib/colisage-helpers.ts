import { COMMUNES_ABIDJAN, normalize as normLoc } from "@/lib/ci-locations";
import type { ModeAcheminement, BLDetail, ColisRow } from "@/lib/colisage-api";
import type { EtiquettePayload } from "@/components/colisage/EtiquetteCarton";

// ---------------------------------------------------------------------------
// keyForLigne
// ---------------------------------------------------------------------------
export function keyForLigne(l: { produit_id: string | null; ligne_id: string }): string {
  return l.produit_id ?? l.ligne_id;
}

// ---------------------------------------------------------------------------
// detectMode
// ---------------------------------------------------------------------------
export type ZonesDirectes = { villes: string[]; communes: string[] };

export type Detection = {
  autoMode: ModeAcheminement | null;
  villeEff: string;
  communeEff: string;
  raison: string;
};

export function detectMode(
  villeEff: string,
  communeEff: string,
  zonesDirectes?: ZonesDirectes,
): Detection {
  const v = normLoc(villeEff);
  const c = normLoc(communeEff);

  if (!v && !c) {
    return {
      autoMode: null,
      villeEff,
      communeEff,
      raison: "Aucune ville renseignée",
    };
  }

  const villesDir = (zonesDirectes?.villes ?? ["Abidjan"]).map(normLoc);
  const communesDir = (zonesDirectes?.communes ?? COMMUNES_ABIDJAN).map(normLoc);

  if (v && villesDir.includes(v)) {
    return {
      autoMode: "livraison",
      villeEff,
      communeEff,
      raison: `Ville « ${villeEff} » listée en livraison directe`,
    };
  }
  if (c && communesDir.includes(c)) {
    return {
      autoMode: "livraison",
      villeEff,
      communeEff,
      raison: `Commune « ${communeEff} » listée en livraison directe`,
    };
  }
  return {
    autoMode: "expedition",
    villeEff,
    communeEff,
    raison: `Ville « ${villeEff || "?"} » hors zone de livraison directe`,
  };
}

// ---------------------------------------------------------------------------
// buildEtiquettesPayload
// ---------------------------------------------------------------------------
export function buildEtiquettesPayload(
  colisExistants: ColisRow[],
  bl: BLDetail,
): EtiquettePayload[] {
  return colisExistants.map((c) => ({
    commande: bl.commande_reference,
    facture: bl.facture_reference,
    bl: bl.reference,
    colis_id: c.colis_id,
    client: bl.client_nom,
    etablissement: bl.etablissement,
    representant: bl.representant_nom,
    telephone: bl.telephone,
    ville: bl.ville,
    adresse: bl.adresse,
    nb_cartons: c.nb_cartons ?? 1,
    numero_carton: c.numero_carton ?? 1,
    responsable: c.responsable_nom,
    date: c.date_colisage ?? new Date().toISOString(),
    mode_acheminement: (c.mode_acheminement as ModeAcheminement) ?? "livraison",
    gare_depart: c.gare_depart,
    ville_destination: c.ville_destination,
    gare_responsable: c.gare_responsable,
    gare_telephone: c.gare_telephone,
    produits: bl.lignes.map((l) => ({ designation: l.designation, quantite: l.quantite })),
  }));
}
