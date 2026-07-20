import { createFileRoute } from "@tanstack/react-router";
import { BookOpen } from "lucide-react";
import { ModulePlaceholder } from "@/components/common/ModulePlaceholder";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/ecritures-comptables")({
  component: () => (
    <ModulePlaceholder
      title="Écritures Comptables"
      subtitle="Saisie et consultation des écritures"
      icon={BookOpen}
      color="#14B8A6"
      description="Retrouvez le détail de toutes les écritures comptables. La saisie et la consultation s'effectuent depuis le Journal Comptable."
      shortcuts={[
        { label: "Journal comptable", to: "/comptabilite" },
        { label: "Nouvelle écriture", to: "/comptabilite/nouvelle" },
        { label: "Grand livre", to: "/grand-livre" },
      ]}
      bullets={[
        "Écritures classées par journal et période",
        "Équilibre débit / crédit contrôlé",
        "Traçabilité et pièces justificatives",
      ]}
    />
  ),
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
