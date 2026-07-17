import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Field } from "@/components/tournees/edit/parts";
import { COST_FIELDS, type CostsState } from "./types";

export function NewTourneeCoutsCard({
  costs,
  setCosts,
  coutTotal,
}: {
  costs: CostsState;
  setCosts: (updater: (c: CostsState) => CostsState) => void;
  coutTotal: number;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Coûts (FCFA)</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        {COST_FIELDS.map((c) => (
          <Field key={c.key} label={c.label}>
            <Input
              type="number"
              inputMode="numeric"
              value={costs[c.key] ?? 0}
              onChange={(e) =>
                setCosts((prev) => ({ ...prev, [c.key]: Number(e.target.value) || 0 }))
              }
            />
          </Field>
        ))}
        <div className="flex items-center justify-between pt-2 border-t text-sm font-medium">
          <span>Total</span>
          <span className="tabular-nums">{coutTotal.toLocaleString("fr-FR")}</span>
        </div>
      </CardContent>
    </Card>
  );
}
