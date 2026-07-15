import { createFileRoute } from "@tanstack/react-router";
import { BarChart3 } from "lucide-react";
import { ModulePlaceholder } from "@/components/common/ModulePlaceholder";

export const Route = createFileRoute("/_authenticated/paie-rapports")({
  component: () => (
    <ModulePlaceholder
      title="Rapports de paie"
      subtitle="Analyses de la masse salariale et des cotisations"
      icon={BarChart3}
      color="#F97316"
      description="Analyses détaillées de la masse salariale, du coût employeur, des cotisations sociales, retenues fiscales, primes et indemnités."
      shortcuts={[
        { label: "Tableau de bord Paie", to: "/paie-dashboard" },
        { label: "Déclarations", to: "/paie-declarations" },
      ]}
      bullets={[
        "Masse salariale mensuelle et annuelle",
        "Ventilation par département / rubrique",
        "Comparatifs et évolutions",
      ]}
    />
  ),
});
