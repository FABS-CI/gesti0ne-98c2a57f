import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Percent, RotateCw, TrendingUp, Wallet } from "lucide-react";
import { formatFCFA } from "@/lib/format";
import { usePermissions } from "@/hooks/use-permissions";

interface Props {
  stockValorise: number;
  stats:
    | {
        ca30?: number;
        qte30?: number;
        marge30?: number;
        margePct30?: number;
        rotation90?: number;
        qte90?: number;
      }
    | undefined;
}

export function KpiCards({ stockValorise, stats }: Props) {
  const { has } = usePermissions();
  const canSeeCouts = has("produits.voir_couts");
  const canSeeCA = has("produits.voir_ca") || has("commandes.voir_ca") || has("dashboard.voir_ca");
  const canSeeMarges = has("produits.voir_marges");
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
            <Wallet className="h-4 w-4" /> Stock valorisé
          </CardTitle>
        </CardHeader>
        <CardContent className="font-medium">
          {canSeeCouts ? formatFCFA(stockValorise) : "—"}
        </CardContent>
      </Card>
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
            <TrendingUp className="h-4 w-4" /> CA 30j
          </CardTitle>
        </CardHeader>
        <CardContent className="font-medium text-primary">
          {canSeeCA ? formatFCFA(stats?.ca30 ?? 0) : "—"}
          <div className="text-xs text-muted-foreground">{stats?.qte30 ?? 0} u. vendues</div>
        </CardContent>
      </Card>
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
            <Percent className="h-4 w-4" /> Marge 30j
          </CardTitle>
        </CardHeader>
        <CardContent className="font-medium">
          {canSeeMarges ? (
            <>
              {formatFCFA(stats?.marge30 ?? 0)}
              <div className="text-xs text-muted-foreground">
                {(stats?.margePct30 ?? 0).toFixed(1)} %
              </div>
            </>
          ) : (
            "—"
          )}
        </CardContent>
      </Card>
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
            <RotateCw className="h-4 w-4" /> Rotation 90j
          </CardTitle>
        </CardHeader>
        <CardContent className="font-medium">
          {(stats?.rotation90 ?? 0).toFixed(2)}×
          <div className="text-xs text-muted-foreground">{stats?.qte90 ?? 0} u. vendues</div>
        </CardContent>
      </Card>
    </div>
  );
}
