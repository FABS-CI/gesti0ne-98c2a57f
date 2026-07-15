import { Card, CardContent } from "@/components/ui/card";
import { formatFCFA } from "@/lib/format";

interface Props {
  totalDebit: number;
  totalCredit: number;
}

export function JournalKpis({ totalDebit, totalCredit }: Props) {
  return (
    <div className="grid gap-4 sm:grid-cols-3">
      <Card>
        <CardContent className="p-4">
          <p className="text-xs text-muted-foreground">Total débit</p>
          <p className="text-xl font-bold">{formatFCFA(totalDebit)}</p>
        </CardContent>
      </Card>
      <Card>
        <CardContent className="p-4">
          <p className="text-xs text-muted-foreground">Total crédit</p>
          <p className="text-xl font-bold">{formatFCFA(totalCredit)}</p>
        </CardContent>
      </Card>
      <Card>
        <CardContent className="p-4">
          <p className="text-xs text-muted-foreground">Équilibre</p>
          <p
            className="text-xl font-bold"
            style={{ color: totalDebit === totalCredit ? "#10B981" : "#EF4444" }}
          >
            {totalDebit === totalCredit ? "Équilibré" : "Déséquilibré"}
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
