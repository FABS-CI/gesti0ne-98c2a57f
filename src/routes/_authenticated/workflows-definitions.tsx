import { createFileRoute } from "@tanstack/react-router";
import { GitBranch } from "lucide-react";
import { ResourceManager } from "@/components/crud/ResourceManager";

export const Route = createFileRoute("/_authenticated/workflows-definitions")({
  component: () => (
    <ResourceManager
      config={{
        table: "workflows_definitions",
        idField: "workflow_id",
        title: "Définitions de workflows",
        subtitle: "Modèles d'approbation multi-niveaux",
        icon: GitBranch,
        newLabel: "Nouveau workflow",
        entityLabel: "workflow",
        searchFields: ["nom", "entite_type", "description"],
        csvName: "workflows-definitions",
        columns: [
          { name: "nom", label: "Nom" },
          { name: "entite_type", label: "Entité" },
          { name: "description", label: "Description" },
          {
            name: "actif",
            label: "Actif",
            type: "badge",
            options: [
              { value: "true", label: "Oui", color: "#10B981" },
              { value: "false", label: "Non", color: "#EF4444" },
            ],
          },
        ],
        fields: [
          { name: "nom", label: "Nom", required: true, colSpan: 2 },
          { name: "entite_type", label: "Entité (ex: facture, achat)", required: true },
          {
            name: "actif",
            label: "Actif",
            type: "select",
            default: "true",
            options: [
              { value: "true", label: "Oui" },
              { value: "false", label: "Non" },
            ],
          },
          { name: "description", label: "Description", type: "textarea", colSpan: 2 },
        ],
      }}
    />
  ),
});
