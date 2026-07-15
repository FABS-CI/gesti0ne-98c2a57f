import { createFileRoute } from "@tanstack/react-router";
import { FileCheck } from "lucide-react";
import { ResourceManager, type ResourceConfig } from "@/components/crud/ResourceManager";

export const Route = createFileRoute("/_authenticated/workflow-approvals")({
  component: () => <ResourceManager config={config} />,
});

const types = [
  { value: "achat", label: "Achat" },
  { value: "depense", label: "Dépense" },
  { value: "conge", label: "Congé" },
  { value: "mission", label: "Mission" },
  { value: "autre", label: "Autre" },
];

const statuts = [
  { value: "en_attente", label: "En attente", color: "#F97316" },
  { value: "approuve", label: "Approuvé", color: "#10B981" },
  { value: "rejete", label: "Rejeté", color: "#EF4444" },
];

const config: ResourceConfig = {
  table: "workflow_approvals",
  idField: "approval_id",
  title: "Workflow & Approbations",
  subtitle: "Demandes d'approbation internes",
  icon: FileCheck,
  newLabel: "Nouvelle demande",
  entityLabel: "la demande",
  csvName: "workflow_approvals",
  searchFields: ["reference", "demandeur", "objet"],
  statusFilter: { field: "statut", options: statuts },
  columns: [
    { name: "reference", label: "Référence", type: "mono" },
    { name: "type_demande", label: "Type", type: "badge", options: types },
    { name: "demandeur", label: "Demandeur" },
    { name: "objet", label: "Objet" },
    { name: "montant", label: "Montant", type: "money", align: "right" },
    { name: "statut", label: "Statut", type: "badge", options: statuts },
  ],
  fields: [
    { name: "type_demande", label: "Type", type: "select", options: types, default: "achat" },
    { name: "demandeur", label: "Demandeur", required: true },
    { name: "objet", label: "Objet", type: "textarea" },
    { name: "montant", label: "Montant (FCFA)", type: "money" },
    { name: "date_demande", label: "Date", type: "date" },
    { name: "statut", label: "Statut", type: "select", options: statuts, default: "en_attente" },
    { name: "notes", label: "Notes", type: "textarea" },
  ],
};
