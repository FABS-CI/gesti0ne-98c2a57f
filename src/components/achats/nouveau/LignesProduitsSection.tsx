import { Plus, Trash2, PackagePlus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { ProductSearchSelect } from "@/components/search/ProductSearchSelect";
import { formatFCFA } from "@/lib/format";
import type { Produit } from "@/lib/produits-api";

export type LigneUI = {
  produit_id: string | null;
  reference_produit: string;
  designation: string;
  quantite: number;
  prix_unitaire: number;
};

export const emptyLigne = (): LigneUI => ({
  produit_id: null,
  reference_produit: "",
  designation: "",
  quantite: 1,
  prix_unitaire: 0,
});

type Props = {
  lignes: LigneUI[];
  onUpdate: (i: number, patch: Partial<LigneUI>) => void;
  onAdd: () => void;
  onRemove: (i: number) => void;
  onPick: (i: number, p: Produit | null) => void;
  onOpenQuickCreate: (i: number) => void;
  qteTotale: number;
  montantTotal: number;
};

export function LignesProduitsSection({
  lignes,
  onUpdate,
  onAdd,
  onRemove,
  onPick,
  onOpenQuickCreate,
  qteTotale,
  montantTotal,
}: Props) {
  return (
    <section className="rounded-md border bg-card p-5 space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">2. Produits livrés</h2>
        <Button type="button" variant="outline" size="sm" onClick={onAdd}>
          <Plus className="h-4 w-4 mr-2" />
          Ajouter une ligne
        </Button>
      </div>

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-[35%]">Produit</TableHead>
            <TableHead>Référence</TableHead>
            <TableHead className="text-right w-24">Qté *</TableHead>
            <TableHead className="text-right w-32">Prix achat</TableHead>
            <TableHead className="text-right w-32">Total</TableHead>
            <TableHead className="w-12" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {lignes.map((l, i) => (
            <TableRow key={i}>
              <TableCell>
                <div className="flex gap-1">
                  <div className="flex-1 min-w-0">
                    <ProductSearchSelect
                      value={l.produit_id}
                      onChange={(_id, produit) => onPick(i, produit)}
                    />
                  </div>
                  <Button aria-label="Créer un nouveau produit"
                    type="button"
                    variant="outline"
                    size="icon"
                    title="Créer un nouveau produit"
                    onClick={() => onOpenQuickCreate(i)}
                  >
                    <PackagePlus className="h-4 w-4" />
                  </Button>
                </div>
              </TableCell>
              <TableCell className="font-mono text-xs">{l.reference_produit || "—"}</TableCell>
              <TableCell className="text-right">
                <Input
                  type="number"
                  min={1}
                  value={l.quantite}
                  onChange={(e) => onUpdate(i, { quantite: Number(e.target.value) || 0 })}
                  className="text-right h-9"
                />
              </TableCell>
              <TableCell className="text-right">
                <Input
                  type="number"
                  min={0}
                  value={l.prix_unitaire}
                  onChange={(e) => onUpdate(i, { prix_unitaire: Number(e.target.value) || 0 })}
                  className="text-right h-9"
                />
              </TableCell>
              <TableCell className="text-right font-semibold">
                {formatFCFA((l.quantite || 0) * (l.prix_unitaire || 0))}
              </TableCell>
              <TableCell>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  onClick={() => onRemove(i)}
                  disabled={lignes.length === 1}
                >
                  <Trash2 className="h-4 w-4 text-red-600" />
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>

      <div className="flex justify-end gap-6 border-t pt-4 text-sm">
        <span className="text-muted-foreground">
          Quantité totale : <span className="font-semibold">{qteTotale}</span>
        </span>
        <span className="text-lg font-bold">Montant total : {formatFCFA(montantTotal)}</span>
      </div>
    </section>
  );
}
