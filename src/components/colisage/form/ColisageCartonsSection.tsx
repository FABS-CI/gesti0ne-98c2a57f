import { CheckCircle2, Minus, Plus, X } from "lucide-react";
import { Button } from "@/components/ui/button";
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { ResponsiveTable } from "@/components/layout/ResponsiveTable";
import { keyForLigne } from "@/lib/colisage-helpers";
import type { BLDetail } from "@/lib/colisage-api";
import type { CartonState } from "./colisage-form-types";

type Ecart = {
  key: string;
  designation: string;
  commande: number;
  reparti: number;
  reste: number;
};

export function ColisageCartonsSection({
  cartons,
  ecarts,
  compositionValide,
  lignesCommande,
  attendu,
  reparti,
  addCarton,
  removeCarton,
  addLigne,
  removeLigne,
  updateLigne,
  updateCarton,
}: {
  cartons: CartonState[];
  ecarts: Ecart[];
  compositionValide: boolean;
  lignesCommande: BLDetail["lignes"];
  attendu: Map<string, number>;
  reparti: Map<string, number>;
  addCarton: () => void;
  removeCarton: (ci: number) => void;
  addLigne: (ci: number) => void;
  removeLigne: (ci: number, li: number) => void;
  updateLigne: (
    ci: number,
    li: number,
    patch: Partial<{ produit_id: string; quantite: string }>,
  ) => void;
  updateCarton: (ci: number, patch: Partial<CartonState>) => void;
}) {
  return (
    <div className="mt-6 space-y-4">
      <div className="rounded-md border bg-muted/30 p-3">
        <div className="mb-2 flex items-center justify-between">
          <h3 className="text-sm font-semibold">Répartition des articles</h3>
          {compositionValide ? (
            <span className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-800">
              <CheckCircle2 className="h-3 w-3" /> Répartition complète
            </span>
          ) : (
            <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-800">
              Répartition incomplète
            </span>
          )}
        </div>
        <ResponsiveTable stickyFirstCol>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Article</TableHead>
                <TableHead className="text-right">Commandé</TableHead>
                <TableHead className="text-right">Réparti</TableHead>
                <TableHead className="text-right">Reste</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {ecarts.map((r) => (
                <TableRow key={r.key}>
                  <TableCell>{r.designation}</TableCell>
                  <TableCell className="text-right">{r.commande}</TableCell>
                  <TableCell className="text-right">{r.reparti}</TableCell>
                  <TableCell
                    className={`text-right font-semibold ${r.reste === 0 ? "text-emerald-600" : r.reste < 0 ? "text-destructive" : "text-amber-600"}`}
                  >
                    {r.reste}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </ResponsiveTable>
      </div>

      {cartons.map((c, ci) => (
        <Card key={ci} className="border-2">
          <CardHeader className="flex flex-row items-center justify-between pb-3">
            <CardTitle className="text-base">Carton {ci + 1}</CardTitle>
            {cartons.length > 1 && (
              <Button type="button" variant="ghost" size="sm" onClick={(e) => { e.preventDefault(); removeCarton(ci); }}>
                <X className="mr-1 h-4 w-4" /> Retirer
              </Button>
            )}
          </CardHeader>
          <CardContent className="space-y-3">
            <div>
              <Label>Observations</Label>
              <Input
                value={c.observations}
                onChange={(e) => updateCarton(ci, { observations: e.target.value })}
              />
            </div>
            <div className="space-y-2">
              <Label>Articles du carton</Label>
              {c.lignes.map((li, lj) => {
                const currentQte = parseInt(li.quantite || "0", 10) || 0;
                const restant = li.produit_id
                  ? (attendu.get(li.produit_id) ?? 0) -
                    (reparti.get(li.produit_id) ?? 0) +
                    currentQte
                  : null;
                const optionsDisponibles = lignesCommande.filter((l) => {
                  const k = keyForLigne(l);
                  if (k === li.produit_id) return true;
                  return (attendu.get(k) ?? 0) - (reparti.get(k) ?? 0) > 0;
                });
                return (
                  <div key={lj} className="grid grid-cols-[1fr,110px,auto] gap-2">
                    <Select
                      value={li.produit_id}
                      onValueChange={(v) => updateLigne(ci, lj, { produit_id: v })}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Choisir un article…" />
                      </SelectTrigger>
                      <SelectContent>
                        {optionsDisponibles.length === 0 ? (
                          <div className="px-2 py-1.5 text-xs text-muted-foreground">
                            Tous les articles ont été répartis
                          </div>
                        ) : (
                          optionsDisponibles
                            .filter((l) => {
                              const k = keyForLigne(l);
                              const dispoTotal = (attendu.get(k) ?? 0) - (reparti.get(k) ?? 0);
                              const dispoLigne = k === li.produit_id ? dispoTotal + currentQte : dispoTotal;
                              return dispoLigne > 0;
                            })
                            .map((l) => {
                              const k = keyForLigne(l);
                              const dispoTotal = (attendu.get(k) ?? 0) - (reparti.get(k) ?? 0);
                              const dispoAffiche = k === li.produit_id ? dispoTotal + currentQte : dispoTotal;
                              return (
                                <SelectItem key={k} value={k}>
                                  {l.designation} — reste {dispoAffiche} / {l.quantite}
                                </SelectItem>
                              );
                            })
                        )}
                      </SelectContent>
                    </Select>
                    <Input
                      type="number"
                      min={0}
                      max={restant ?? undefined}
                      placeholder="Qté"
                      value={li.quantite ?? ""}
                      onChange={(e) => {
                        const val = e.target.value;
                        if (val === "") {
                          updateLigne(ci, lj, { quantite: "" });
                          return;
                        }
                        const n = parseInt(val, 10);
                        if (Number.isNaN(n) || n < 0) return;
                        const maxDispo = li.produit_id
                          ? (attendu.get(li.produit_id) ?? 0) -
                            (reparti.get(li.produit_id) ?? 0) +
                            currentQte
                          : n;
                        updateLigne(ci, lj, { quantite: String(Math.min(n, maxDispo)) });
                      }}
                    />
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={(e) => { e.preventDefault(); removeLigne(ci, lj); }}
                      disabled={c.lignes.length === 1}
                    >
                      <Minus className="h-4 w-4" />
                    </Button>
                    {restant !== null && (
                      <div className="col-span-3 -mt-1 text-xs text-muted-foreground">
                        Restant disponible pour cet article : <strong>{restant}</strong>
                      </div>
                    )}
                  </div>
                );
              })}
              <Button type="button" variant="outline" size="sm" onClick={(e) => { e.preventDefault(); addLigne(ci); }}>
                <Plus className="mr-1 h-4 w-4" /> Ajouter un article
              </Button>
            </div>
          </CardContent>
        </Card>
      ))}
      <div>
        <Button type="button" variant="secondary" size="sm" onClick={(e) => { e.preventDefault(); addCarton(); }}>
          <Plus className="mr-1 h-4 w-4" /> Ajouter un carton
        </Button>
      </div>
    </div>
  );
}
