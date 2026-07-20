import { createFileRoute } from "@tanstack/react-router";
import { ListTree } from "lucide-react";
import { ModulePlaceholder } from "@/components/common/ModulePlaceholder";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/plan-comptable")({
  component: () => (
    <ModulePlaceholder
      title="Plan Comptable"
      subtitle="Référentiel SYSCOHADA"
      icon={ListTree}
      color="#3B82F6"
      description="Consultation du plan comptable SYSCOHADA utilisé par l'ERP : classes, comptes principaux, comptes de tiers et comptes analytiques."
      shortcuts={[
        { label: "Balance", to: "/balance" },
        { label: "Grand livre", to: "/grand-livre" },
      ]}
      bullets={[
        "Classes 1 à 9 SYSCOHADA",
        "Comptes clients (411), fournisseurs (401), trésorerie (5)",
        "Recherche rapide par numéro ou libellé",
      ]}
    />
  ),
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
