import { Card, CardContent } from "@/components/ui/card";
import { formatFCFA } from "@/lib/format";
import type { RapportKpi } from "@/lib/rapports-api";

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <CardContent className="p-3">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="mt-1 truncate text-lg font-semibold">{value}</p>
      </CardContent>
    </Card>
  );
}

export function RapportKpisGrid({ data }: { data: RapportKpi | undefined }) {
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <Kpi label="Chiffre d'affaires" value={formatFCFA(data?.ca ?? 0)} />
      <Kpi label="Qté vendue" value={String(data?.qte_vendue ?? 0)} />
      <Kpi label="Qté facturée" value={String(data?.qte_facturee ?? 0)} />
      <Kpi label="Nb factures" value={String(data?.nb_factures ?? 0)} />
      <Kpi label="Clients actifs" value={String(data?.nb_clients ?? 0)} />
      <Kpi label="Prix moyen" value={formatFCFA(data?.prix_moyen ?? 0)} />
      <Kpi label="Panier moyen" value={formatFCFA(data?.panier_moyen ?? 0)} />
      <Kpi label="Top produit" value={data?.top_produit ?? "—"} />
    </div>
  );
}
