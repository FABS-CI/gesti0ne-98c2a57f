import { Card, CardContent } from "@/components/ui/card";
import { formatFCFA } from "@/lib/format";

type Props = { total: number; paye: number; du: number };

export function FacturesKpis({ total, paye, du }: Props) {
  return (
    <div className="grid gap-4 sm:grid-cols-3">
      <Card>
        <CardContent className="p-4">
          <p className="text-xs text-muted-foreground">Total facturé</p>
          <p className="text-xl font-bold">{formatFCFA(total)}</p>
        </CardContent>
      </Card>
      <Card>
        <CardContent className="p-4">
          <p className="text-xs text-muted-foreground">Encaissé</p>
          <p className="text-xl font-bold text-emerald-600">{formatFCFA(paye)}</p>
        </CardContent>
      </Card>
      <Card>
        <CardContent className="p-4">
          <p className="text-xs text-muted-foreground">Reste dû</p>
          <p className="text-xl font-bold text-red-600">{formatFCFA(du)}</p>
        </CardContent>
      </Card>
    </div>
  );
}
