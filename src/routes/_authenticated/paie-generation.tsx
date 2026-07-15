import { createFileRoute } from "@tanstack/react-router";
import { PlayCircle } from "lucide-react";
import { ModulePlaceholder } from "@/components/common/ModulePlaceholder";

export const Route = createFileRoute("/_authenticated/paie-generation")({
  component: () => (
    <ModulePlaceholder
      title="Génération mensuelle des paies"
      subtitle="Génération automatique des bulletins pour une période donnée"
      icon={PlayCircle}
      color="#10B981"
      description="Lancez la génération de la paie du mois pour l'ensemble des salariés actifs, ou pour une sélection ciblée. Le moteur applique les rubriques, paramètres CNPS/ITS/IGR et cumuls annuels."
      shortcuts={[
        { label: "Nouveau bulletin", to: "/paie/nouveau" },
        { label: "Paramètres", to: "/paie-parametres" },
        { label: "Rubriques", to: "/paie-rubriques" },
      ]}
      bullets={[
        "Génération en masse par département ou en individuel",
        "Prévisualisation avant validation",
        "Journalisation complète des exécutions",
      ]}
    />
  ),
});
