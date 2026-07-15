import { Plus, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { CustomField } from "@/lib/paie-nouveau-helpers";

interface Props {
  customFields: CustomField[];
  setCustomFields: React.Dispatch<React.SetStateAction<CustomField[]>>;
  observations: string;
  setObservations: (v: string) => void;
}

export function CustomFieldsCard({
  customFields,
  setCustomFields,
  observations,
  setObservations,
}: Props) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle className="text-base">Champs personnalisés (RH / Compta)</CardTitle>
        <Button
          size="sm"
          variant="outline"
          onClick={() => setCustomFields((f) => [...f, { label: "", valeur: "" }])}
        >
          <Plus className="mr-2 h-3 w-3" /> Ajouter un champ
        </Button>
      </CardHeader>
      <CardContent className="space-y-2">
        {customFields.length === 0 && (
          <p className="text-xs text-muted-foreground">
            Aucun champ. Ajoutez des références internes, notes ou informations complémentaires qui
            seront rendues automatiquement dans le PDF.
          </p>
        )}
        {customFields.map((c, i) => (
          <div key={i} className="grid grid-cols-[1fr_2fr_auto] gap-2">
            <Input
              placeholder="Libellé (ex. Réf. contrat)"
              value={c.label}
              onChange={(e) =>
                setCustomFields((arr) =>
                  arr.map((x, k) => (k === i ? { ...x, label: e.target.value } : x)),
                )
              }
            />
            <Input
              placeholder="Valeur"
              value={c.valeur}
              onChange={(e) =>
                setCustomFields((arr) =>
                  arr.map((x, k) => (k === i ? { ...x, valeur: e.target.value } : x)),
                )
              }
            />
            <Button
              size="icon"
              variant="ghost"
              aria-label="Supprimer le champ"
              onClick={() => setCustomFields((arr) => arr.filter((_, k) => k !== i))}
            >
              <Trash2 className="h-4 w-4 text-destructive" />
            </Button>
          </div>
        ))}
        <div>
          <Label>Observations</Label>
          <Textarea
            rows={3}
            value={observations}
            onChange={(e) => setObservations(e.target.value)}
            placeholder="Mentions particulières (facultatif)…"
          />
        </div>
      </CardContent>
    </Card>
  );
}
