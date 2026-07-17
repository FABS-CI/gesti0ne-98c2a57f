export type Tournee = {
  tournee_id: string;
  reference: string;
  date_tournee: string | null;
  responsable_nom: string | null;
  chauffeur_nom: string | null;
  vehicule_id: string | null;
  statut: string;
  notes: string | null;
  cout_carburant: number | null;
  cout_peages: number | null;
  cout_repas: number | null;
  cout_expeditions: number | null;
  cout_manutentions: number | null;
  cout_autres: number | null;
  cout_livraison: number | null;
  type_tournee: string | null;
  cout_total: number | null;
  validation_statut?: string | null;
  validation_at?: string | null;
  validation_commentaire?: string | null;
  mode_reglement?: string | null;
  nb_colis: number | null;
  nb_cartons: number | null;
  nb_clients: number | null;
  cloture_mode: string | null;
  cloture_at: string | null;
  cloture_by: string | null;
};

export type ColisRow = {
  colis_id: string;
  reference: string | null;
  nb_cartons: number | null;
  commande_id: string | null;
  destinataire: string | null;
  ville_livraison: string | null;
  quartier: string | null;
  livreur_nom: string | null;
};

export type CommandeRow = { commande_id: string; client_id: string | null; client_nom: string | null };
export type Vehicule = { vehicule_id: string; immatriculation: string | null };

export const STATUTS = [
  { value: "preparee", label: "Préparée" },
  { value: "en_cours", label: "En cours" },
  { value: "terminee", label: "Terminée" },
  { value: "annulee", label: "Annulée" },
];

export const COST_FIELDS: Array<{ key: keyof Tournee; label: string }> = [
  { key: "cout_carburant", label: "Carburant" },
  { key: "cout_peages", label: "Péages" },
  { key: "cout_repas", label: "Repas" },
  { key: "cout_livraison", label: "Frais de livraison" },
  { key: "cout_expeditions", label: "Expéditions" },
  { key: "cout_manutentions", label: "Manutentions" },
  { key: "cout_autres", label: "Autres" },
];
