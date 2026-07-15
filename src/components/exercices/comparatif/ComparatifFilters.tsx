import { Card, CardContent } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { ExerciceLite } from "@/hooks/use-exercices-comparatif";

export const SORT_KEYS = ["code", "ca", "encaisse", "achats", "resultat"] as const;
export type SortKey = (typeof SORT_KEYS)[number];

type Props = {
  exercices: ExerciceLite[];
  selected: Set<string>;
  onSelectedChange: (next: Set<string>) => void;
  sortKey: SortKey;
  onSortKey: (k: SortKey) => void;
  sortDir: "asc" | "desc";
  onSortDir: (d: "asc" | "desc") => void;
  showPct: boolean;
  onShowPct: (v: boolean) => void;
};

export function ComparatifFilters({
  exercices,
  selected,
  onSelectedChange,
  sortKey,
  onSortKey,
  sortDir,
  onSortDir,
  showPct,
  onShowPct,
}: Props) {
  const toggleExercice = (id: string) => {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    onSelectedChange(next);
  };
  return (
    <Card>
      <CardContent className="flex flex-wrap items-end gap-4 p-4">
        <div className="flex-1 min-w-[240px]">
          <div className="mb-2 flex items-center justify-between">
            <p className="text-xs font-medium text-muted-foreground">Exercices affichés</p>
            <div className="flex gap-2 text-xs">
              <button
                type="button"
                className="text-primary hover:underline"
                onClick={() => onSelectedChange(new Set(exercices.map((e) => e.exercice_id)))}
              >
                Tout
              </button>
              <button
                type="button"
                className="text-muted-foreground hover:underline"
                onClick={() => onSelectedChange(new Set())}
              >
                Aucun
              </button>
            </div>
          </div>
          <div className="flex flex-wrap gap-3">
            {exercices.map((ex) => (
              <label
                key={ex.exercice_id}
                className="flex items-center gap-2 rounded-md border px-2 py-1 text-sm"
              >
                <Checkbox
                  checked={selected.has(ex.exercice_id)}
                  onCheckedChange={() => toggleExercice(ex.exercice_id)}
                />
                {ex.code}
              </label>
            ))}
          </div>
        </div>
        <div className="min-w-[180px]">
          <label className="text-xs text-muted-foreground">Trier par</label>
          <Select value={sortKey} onValueChange={(v) => onSortKey(v as SortKey)}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="code">Exercice</SelectItem>
              <SelectItem value="ca">CA facturé</SelectItem>
              <SelectItem value="encaisse">Encaissé</SelectItem>
              <SelectItem value="achats">Achats</SelectItem>
              <SelectItem value="resultat">Résultat</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="min-w-[140px]">
          <label className="text-xs text-muted-foreground">Ordre</label>
          <Select value={sortDir} onValueChange={(v) => onSortDir(v as "asc" | "desc")}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="asc">Croissant</SelectItem>
              <SelectItem value="desc">Décroissant</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <label className="flex items-center gap-2 pb-2 text-sm">
          <Checkbox checked={showPct} onCheckedChange={(v) => onShowPct(v === true)} />
          Afficher les % d'évolution
        </label>
      </CardContent>
    </Card>
  );
}
