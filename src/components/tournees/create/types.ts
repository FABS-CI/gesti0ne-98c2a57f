export type ColisRow = {
  colis_id: string;
  reference: string | null;
  bl_id: string | null;
  numero_carton: number | null;
  nb_cartons: number | null;
  commande_id: string | null;
  destinataire: string | null;
  ville_livraison: string | null;
  quartier: string | null;
  vehicule: string | null;
  livreur_nom: string | null;
  responsable_nom: string | null;
  transporteur: string | null;
  mode_acheminement: string | null;
  date_colisage: string | null;
};

export type BLStatusRow = { bl_id: string; statut: string | null };
export type Vehicule = { vehicule_id: string; immatriculation: string | null };

export type CommandeRow = {
  commande_id: string;
  reference: string | null;
  client_id: string | null;
  client_nom: string | null;
  representant_nom: string | null;
  commercial_nom: string | null;
  total_quantite: number | null;
  depot_id: string | null;
  ville: string | null;
};

export type DepotRow = { depot_id: string; nom: string | null };

export type TourneeFormState = {
  reference: string;
  date_tournee: string;
  heure_depart: string;
  depot_depart_id: string;
  responsable_nom: string;
  chauffeur_nom: string;
  vehicule_id: string;
  statut: string;
  type_tournee: string;
  notes: string;
};

export type CostsState = Record<string, number>;

export const COST_FIELDS: Array<{ key: string; label: string }> = [
  { key: "cout_carburant", label: "Carburant" },
  { key: "cout_peages", label: "Péages" },
  { key: "cout_repas", label: "Repas" },
  { key: "cout_livraison", label: "Frais de livraison" },
  { key: "cout_expeditions", label: "Expéditions" },
  { key: "cout_manutentions", label: "Manutentions" },
  { key: "cout_autres", label: "Autres" },
];

export function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

export function defaultRef() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const rand = Math.floor(1000 + Math.random() * 9000);
  return `TRN-${y}${m}${day}-${rand}`;
}
