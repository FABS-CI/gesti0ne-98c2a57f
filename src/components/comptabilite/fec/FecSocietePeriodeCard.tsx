import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { SOCIETES } from "@/lib/fec-helpers";

interface Props {
  societe: string;
  setSociete: (v: string) => void;
  preset: string;
  onPreset: (v: string) => void;
  dateFrom: string;
  dateTo: string;
  setDateFrom: (v: string) => void;
  setDateTo: (v: string) => void;
  setPreset: (v: string) => void;
}

export function FecSocietePeriodeCard({
  societe,
  setSociete,
  preset,
  onPreset,
  dateFrom,
  dateTo,
  setDateFrom,
  setDateTo,
  setPreset,
}: Props) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Société & période d'exercice</CardTitle>
      </CardHeader>
      <CardContent className="grid gap-4 md:grid-cols-4">
        <div>
          <Label>Société</Label>
          <Select value={societe} onValueChange={setSociete}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {SOCIETES.map((s) => (
                <SelectItem key={s.code} value={s.code}>
                  {s.nom}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div>
          <Label>Période</Label>
          <Select value={preset} onValueChange={onPreset}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="mois">Mois courant</SelectItem>
              <SelectItem value="trimestre">Trimestre courant</SelectItem>
              <SelectItem value="annee">Année courante</SelectItem>
              <SelectItem value="annee_prec">Exercice N-1</SelectItem>
              <SelectItem value="custom">Personnalisée</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div>
          <Label>Du</Label>
          <Input
            type="date"
            value={dateFrom}
            onChange={(e) => {
              setPreset("custom");
              setDateFrom(e.target.value);
            }}
          />
        </div>
        <div>
          <Label>Au</Label>
          <Input
            type="date"
            value={dateTo}
            onChange={(e) => {
              setPreset("custom");
              setDateTo(e.target.value);
            }}
          />
        </div>
      </CardContent>
    </Card>
  );
}
