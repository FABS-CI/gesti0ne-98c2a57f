import { createFileRoute } from "@tanstack/react-router";
import { Download } from "lucide-react";
import { ModulePlaceholder } from "@/components/common/ModulePlaceholder";

export const Route = createFileRoute("/_authenticated/paie-exports")({
  component: () => (
    <ModulePlaceholder
      title="Exports Paie (PDF / Excel)"
      subtitle="Exports groupés des bulletins et récapitulatifs"
      icon={Download}
      color="#14B8A6"
      description="Générez des exports PDF ou Excel des bulletins d'une période, du livre de paie, des cotisations et récapitulatifs de masse salariale."
      shortcuts={[
        { label: "Bulletins", to: "/paie" },
        { label: "Historique", to: "/paie-historique" },
      ]}
      bullets={[
        "Export PDF multi-bulletins A4",
        "Export Excel du livre de paie",
        "Récapitulatifs mensuels et annuels",
      ]}
    />
  ),
});
