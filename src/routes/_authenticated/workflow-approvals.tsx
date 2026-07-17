import { createFileRoute } from "@tanstack/react-router";
import { FileCheck } from "lucide-react";
import { ResourceManager, type ResourceConfig } from "@/components/crud/ResourceManager";

export const Route = createFileRoute("/_authenticated/workflow-approvals")({
  component: () => <ResourceManager config={config} />,
});

const workflows = [
  { value: "achat", label: "Achat" },
  { value: "depense", label: "Dépense" },
  { value: "conge", label: "Congé" },
  { value: "mission", label: "Mission" },
  { value: "facture", label: "Facture" },
  { value: "autre", label: "Autre" },
];

const statuts = [
  { value: "en_attente", label: "En attente", color: "#F97316" },
  { value: "approuve", label: "Approuvé", color: "#10B981" },
  { value: "rejete", label: "Rejeté", color: "#EF4444" },
];

const config: ResourceConfig = {
  table: "workflow_approvals",
  idField: "id",
  title: "Workflow & Approbations",
  subtitle: "Demandes d'approbation internes",
  icon: FileCheck,
  newLabel: "Nouvelle demande",
  entityLabel: "la demande",
  csvName: "workflow_approvals",
  searchFields: ["reference", "demandeur_nom", "workflow_code", "entity_type"],
  statusFilter: { field: "statut", options: statuts },
  columns: [
    { name: "reference", label: "Référence", type: "mono" },
    { name: "workflow_code", label: "Workflow", type: "badge", options: workflows },
    { name: "entity_type", label: "Entité" },
    { name: "demandeur_nom", label: "Demandeur" },
    { name: "statut", label: "Statut", type: "badge", options: statuts },
  ],
  fields: [
    { name: "workflow_code", label: "Workflow", type: "select", options: workflows, default: "achat" },
    { name: "entity_type", label: "Type d'entité (ex: facture, achat)" },
    { name: "reference", label: "Référence" },
    { name: "demandeur_nom", label: "Demandeur", required: true },
    { name: "statut", label: "Statut", type: "select", options: statuts, default: "en_attente" },
    { name: "commentaire", label: "Commentaire", type: "textarea", colSpan: 2 },
  ],
};
