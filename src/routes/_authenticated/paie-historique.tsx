import { createFileRoute } from "@tanstack/react-router";
import { History } from "lucide-react";
import { ModulePlaceholder } from "@/components/common/ModulePlaceholder";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/paie-historique")({
  component: () => (
    <ModulePlaceholder
      title="Historique des paies"
      subtitle="Consultation de tous les bulletins archivés"
      icon={History}
      color="#8B5CF6"
      description="Retrouvez l'ensemble des bulletins de paie générés, avec périodes, salariés, montants, statuts de validation et actions d'impression / téléchargement."
      shortcuts={[
        { label: "Bulletins", to: "/paie" },
        { label: "Tableau de bord Paie", to: "/paie-dashboard" },
      ]}
      bullets={[
        "Filtrage par période, salarié, statut",
        "Téléchargement PDF individuel",
        "Traçabilité des validations et paiements",
      ]}
    />
  ),
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
