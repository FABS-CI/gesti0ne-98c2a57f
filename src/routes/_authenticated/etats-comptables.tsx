import { createFileRoute } from "@tanstack/react-router";
import { FileText } from "lucide-react";
import { ModulePlaceholder } from "@/components/common/ModulePlaceholder";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/etats-comptables")({
  component: () => (
    <ModulePlaceholder
      title="États Comptables"
      subtitle="Bilan, Compte de résultat, TAFIRE"
      icon={FileText}
      color="#8B5CF6"
      description="Édition des états comptables réglementaires : bilan, compte de résultat, tableau des flux de trésorerie et annexes selon SYSCOHADA révisé."
      shortcuts={[
        { label: "Balance", to: "/balance" },
        { label: "Grand livre", to: "/grand-livre" },
        { label: "Export FEC", to: "/comptabilite/fec" },
      ]}
      bullets={["Bilan actif / passif", "Compte de résultat", "Annexes réglementaires"]}
    />
  ),
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});
