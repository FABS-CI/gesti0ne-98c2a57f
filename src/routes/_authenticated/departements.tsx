import { createFileRoute } from "@tanstack/react-router";
import { Building2 } from "lucide-react";
import { ResourceManager, type ResourceConfig } from "@/components/crud/ResourceManager";

export const Route = createFileRoute("/_authenticated/departements")({
  component: () => <ResourceManager config={config} />,
});

const config: ResourceConfig = {
  table: "departements",
  idField: "departement_id",
  title: "Départements",
  subtitle: "Services et départements de l'entreprise",
  icon: Building2,
  newLabel: "Nouveau département",
  entityLabel: "le département",
  csvName: "departements",
  searchFields: ["nom", "responsable"],
  columns: [
    { name: "nom", label: "Nom" },
    { name: "responsable", label: "Responsable" },
    { name: "description", label: "Description" },
  ],
  fields: [
    { name: "nom", label: "Nom", required: true, colSpan: 2 },
    { name: "responsable", label: "Responsable", colSpan: 2 },
    { name: "description", label: "Description", type: "textarea" },
  ],
};
