import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface Props {
  pageMargin: number;
  setPageMargin: (v: number) => void;
  baseFontSize: number;
  setBaseFontSize: (v: number) => void;
}

export function PageLayoutCard({
  pageMargin,
  setPageMargin,
  baseFontSize,
  setBaseFontSize,
}: Props) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Mise en page A4</CardTitle>
      </CardHeader>
      <CardContent className="grid grid-cols-2 gap-3">
        <div>
          <Label>Marges (mm) — 4 à 30</Label>
          <Input
            type="number"
            min={4}
            max={30}
            step={0.5}
            value={pageMargin}
            onChange={(e) => setPageMargin(Math.max(4, Math.min(30, Number(e.target.value) || 10)))}
          />
        </div>
        <div>
          <Label>Taille police corps (pt) — 6 à 12</Label>
          <Input
            type="number"
            min={6}
            max={12}
            step={0.1}
            value={baseFontSize}
            onChange={(e) =>
              setBaseFontSize(Math.max(6, Math.min(12, Number(e.target.value) || 8.5)))
            }
          />
        </div>
        <p className="col-span-2 text-xs text-muted-foreground">
          Ces réglages garantissent un rendu identique sur tous les navigateurs et systèmes
          (impression / export PDF A4).
        </p>
      </CardContent>
    </Card>
  );
}
