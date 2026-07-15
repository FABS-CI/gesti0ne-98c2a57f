import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { SupplierSearchSelect } from "@/components/search/SupplierSearchSelect";
import type { Depot } from "@/lib/depots-api";

type Props = {
  fournisseurId: string;
  onFournisseurChange: (id: string) => void;
  depotId: string;
  onDepotChange: (id: string) => void;
  depotsActifs: Depot[];
  date: string;
  onDateChange: (d: string) => void;
  referenceFournisseur: string;
  onReferenceFournisseurChange: (v: string) => void;
  notes: string;
  onNotesChange: (v: string) => void;
};

export function InfosGeneralesSection({
  fournisseurId,
  onFournisseurChange,
  depotId,
  onDepotChange,
  depotsActifs,
  date,
  onDateChange,
  referenceFournisseur,
  onReferenceFournisseurChange,
  notes,
  onNotesChange,
}: Props) {
  return (
    <section className="rounded-md border bg-card p-5 space-y-4">
      <h2 className="text-lg font-semibold">1. Informations générales</h2>
      <div className="grid gap-4 md:grid-cols-2">
        <div>
          <Label>Numéro</Label>
          <Input value="(généré automatiquement)" readOnly disabled />
        </div>
        <div>
          <Label htmlFor="date">Date *</Label>
          <Input
            id="date"
            type="date"
            value={date}
            onChange={(e) => onDateChange(e.target.value)}
          />
        </div>
        <div>
          <Label>Fournisseur *</Label>
          <SupplierSearchSelect
            value={fournisseurId}
            onChange={(id) => onFournisseurChange(id ?? "")}
          />
        </div>
        <div>
          <Label>Dépôt de destination *</Label>
          <Select value={depotId} onValueChange={onDepotChange}>
            <SelectTrigger>
              <SelectValue placeholder="— Sélectionnez un dépôt —" />
            </SelectTrigger>
            <SelectContent>
              {depotsActifs.map((d) => (
                <SelectItem key={d.depot_id} value={d.depot_id}>
                  {d.nom} {d.is_principal ? "(principal)" : ""}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div>
          <Label>Référence fournisseur</Label>
          <Input
            value={referenceFournisseur}
            onChange={(e) => onReferenceFournisseurChange(e.target.value)}
            placeholder="Ex : BL n°…"
          />
        </div>
        <div className="md:col-span-2">
          <Label>Observations</Label>
          <Textarea value={notes} onChange={(e) => onNotesChange(e.target.value)} rows={2} />
        </div>
      </div>
    </section>
  );
}
