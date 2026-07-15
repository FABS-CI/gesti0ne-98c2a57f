import { Calculator } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatFCFA } from "@/lib/format";
import type { EngineResult } from "@/lib/paie/engine";

function Row({
  label,
  value,
  strong,
  muted,
  highlight,
}: {
  label: string;
  value: number;
  strong?: boolean;
  muted?: boolean;
  highlight?: boolean;
}) {
  return (
    <div className="flex justify-between">
      <span className={muted ? "text-muted-foreground" : ""}>{label}</span>
      <span
        className={[
          strong ? "font-semibold" : "",
          highlight ? "text-lg font-bold text-primary" : "",
          value < 0 ? "text-destructive" : "",
        ].join(" ")}
      >
        {formatFCFA(Math.abs(value))}
      </span>
    </div>
  );
}

export function RecapCard({ result }: { result: EngineResult | null }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          <Calculator className="h-4 w-4" /> Récapitulatif
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 text-sm">
        <Row label="Salaire brut" value={result?.salaireBrut ?? 0} strong />
        <Row label="Base imposable" value={result?.salaireBrutImposable ?? 0} muted />
        <Row label="CNPS salarié" value={-(result?.cnpsSalarie ?? 0)} />
        <Row label="CMU salarié" value={-(result?.cmuSalarie ?? 0)} />
        <Row label="ITS" value={-(result?.its ?? 0)} />
        <Row label="Contribution Nationale" value={-(result?.cn ?? 0)} />
        <Row label="Total retenues" value={-(result?.totalRetenues ?? 0)} strong />
        <div className="border-t pt-2">
          <Row label="Salaire net à payer" value={result?.salaireNet ?? 0} highlight />
        </div>
        <div className="border-t pt-2 text-xs text-muted-foreground">
          <Row label="Charges patronales" value={result?.totalPatronales ?? 0} muted />
          <Row label="Coût total employeur" value={result?.coutEmployeur ?? 0} muted />
        </div>
      </CardContent>
    </Card>
  );
}
