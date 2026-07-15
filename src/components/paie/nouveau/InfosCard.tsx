import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { EmployeeSearchSelect } from "@/components/search/EmployeeSearchSelect";
import type { Employe } from "@/lib/rh-api";

interface Props {
  employes: Employe[] | undefined;
  employeId: string;
  onSelectEmploye: (id: string) => void;
  periode: string;
  setPeriode: (v: string) => void;
  salaireBase: number;
  setSalaireBase: (v: number) => void;
  primes: number;
  setPrimes: (v: number) => void;
  heuresSup: number;
  setHeuresSup: (v: number) => void;
}

export function InfosCard(p: Props) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Informations</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <div>
          <Label>Employé *</Label>
          <EmployeeSearchSelect
            value={p.employeId || null}
            onChange={(id) => p.onSelectEmploye(id ?? "")}
          />
        </div>
        <div>
          <Label>Période *</Label>
          <Input
            value={p.periode}
            onChange={(e) => p.setPeriode(e.target.value)}
            placeholder="ex: Juillet 2026"
          />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label>Salaire de base (FCFA)</Label>
            <Input
              type="number"
              value={p.salaireBase}
              onChange={(e) => p.setSalaireBase(Number(e.target.value) || 0)}
            />
          </div>
          <div>
            <Label>Primes / indemnités</Label>
            <Input
              type="number"
              value={p.primes}
              onChange={(e) => p.setPrimes(Number(e.target.value) || 0)}
            />
          </div>
          <div>
            <Label>Heures supplémentaires</Label>
            <Input
              type="number"
              value={p.heuresSup}
              onChange={(e) => p.setHeuresSup(Number(e.target.value) || 0)}
            />
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
