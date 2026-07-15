import { lazy, Suspense } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { formatFCFA } from "@/lib/format";
import { buildMonthlyStats } from "@/lib/client-detail-helpers";
import type { ClientRelations } from "@/lib/clients-api";

const ClientCaBarChart = lazy(() => import("@/components/charts/ClientCaBarChart"));

interface ClientStatsTabProps {
  factures: ClientRelations["factures"];
  commandesCount: number;
}

export function ClientStatsTab({ factures, commandesCount }: ClientStatsTabProps) {
  const caFacture = factures.reduce((s, f) => s + Number(f.montant_total), 0);
  const monthlyStats = buildMonthlyStats(factures);
  return (
    <div className="space-y-4">
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm text-muted-foreground">
            CA facturé par mois (12 derniers mois)
          </CardTitle>
        </CardHeader>
        <CardContent className="h-72">
          <Suspense fallback={<Skeleton className="h-full w-full" />}>
            <ClientCaBarChart data={monthlyStats} />
          </Suspense>
        </CardContent>
      </Card>
      <div className="grid gap-4 sm:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">Nb commandes</CardTitle>
          </CardHeader>
          <CardContent className="text-xl font-bold">{commandesCount}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">Nb factures</CardTitle>
          </CardHeader>
          <CardContent className="text-xl font-bold">{factures.length}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">Panier moyen</CardTitle>
          </CardHeader>
          <CardContent className="text-xl font-bold">
            {formatFCFA(factures.length ? caFacture / factures.length : 0)}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
