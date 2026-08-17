export type CartonState = {
  poids: string;
  format: string;
  observations: string;
  lignes: { produit_id: string; quantite: string }[];
};

export type Responsable = {
  preparateur_id: string;
  nom: string;
  poste: string | null;
  telephone: string | null;
};

export type Livreur = {
  livreur_id: string;
  nom: string;
  telephone: string | null;
  vehicule_defaut: string | null;
  immatriculation: string | null;
  societe: string | null;
};

export type ClientInfo =
  | { client_id: string; ville: string | null; commune: string | null; quartier: string | null }
  | null
  | undefined;
