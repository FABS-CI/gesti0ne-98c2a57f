import { createFileRoute } from "@tanstack/react-router";
import { User } from "lucide-react";
import { ResourceManager, type ResourceConfig } from "@/components/crud/ResourceManager";

const config: ResourceConfig = {
  table: "livreurs",
  idField: "livreur_id",
  title: "Livreurs",
  subtitle: "Fiche des livreurs (aucun accès à l'application, données à titre logistique)",
  icon: User,
  newLabel: "Nouveau livreur",
  entityLabel: "le livreur",
  csvName: "livreurs",
  searchFields: ["nom", "telephone", "societe", "immatriculation"],
  columns: [
    { name: "nom", label: "Nom" },
    { name: "telephone", label: "Téléphone" },
    { name: "societe", label: "Société" },
    { name: "vehicule_defaut", label: "Véhicule" },
    { name: "immatriculation", label: "Immatriculation", type: "mono" },
    {
      name: "actif",
      label: "Statut",
      type: "badge",
      options: [
        { value: "true", label: "Actif", color: "#10B981" },
        { value: "false", label: "Inactif", color: "#94A3B8" },
      ],
    },
  ],
  fields: [
    { name: "nom", label: "Nom complet", required: true },
    { name: "telephone", label: "Téléphone" },
    { name: "societe", label: "Société / Employeur" },
    { name: "vehicule_defaut", label: "Véhicule habituel" },
    { name: "immatriculation", label: "Immatriculation" },
    {
      name: "actif",
      label: "Actif",
      type: "select",
      options: [
        { value: "true", label: "Oui" },
        { value: "false", label: "Non" },
      ],
      default: "true",
    },
    { name: "observations", label: "Observations", type: "textarea", colSpan: 2 },
  ],
};

export const Route = createFileRoute("/_authenticated/livreurs")({
  component: () => <ResourceManager config={config} />,
});
