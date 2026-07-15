import { TrendingDown, TrendingUp, Wallet } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { formatFCFA } from "@/lib/format";

type Props = { recettes: number; depenses: number; solde: number };

export function FinancesKpis({ recettes, depenses, solde }: Props) {
  return (
    <div className="grid gap-4 sm:grid-cols-3">
      <Card>
        <CardContent className="flex items-center justify-between p-4">
          <div>
            <p className="text-xs text-muted-foreground">Recettes</p>
            <p className="text-xl font-bold text-emerald-600">{formatFCFA(recettes)}</p>
          </div>
          <TrendingUp className="h-8 w-8 text-emerald-500/40" />
        </CardContent>
      </Card>
      <Card>
        <CardContent className="flex items-center justify-between p-4">
          <div>
            <p className="text-xs text-muted-foreground">Dépenses</p>
            <p className="text-xl font-bold text-red-600">{formatFCFA(depenses)}</p>
          </div>
          <TrendingDown className="h-8 w-8 text-red-500/40" />
        </CardContent>
      </Card>
      <Card>
        <CardContent className="flex items-center justify-between p-4">
          <div>
            <p className="text-xs text-muted-foreground">Solde</p>
            <p className={`text-xl font-bold ${solde >= 0 ? "text-emerald-600" : "text-red-600"}`}>
              {formatFCFA(solde)}
            </p>
          </div>
          <Wallet className="h-8 w-8 text-primary/40" />
        </CardContent>
      </Card>
    </div>
  );
}
