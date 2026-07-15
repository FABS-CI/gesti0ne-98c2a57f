import type { DepotInput } from "@/lib/depots-api";

export const EMPTY_DEPOT: DepotInput = {
  code: "",
  nom: "",
  type_depot: "secondaire",
  description: "",
  pays: "Côte d'Ivoire",
  ville: "",
  commune: "",
  quartier: "",
  adresse: "",
  code_postal: "",
  latitude: null,
  longitude: null,
  responsable: "",
  responsable_email: "",
  telephone: "",
  capacite: null,
  actif: true,
  is_principal: false,
};
