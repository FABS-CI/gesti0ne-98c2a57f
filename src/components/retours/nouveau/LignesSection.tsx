import type { UseFieldArrayReturn, UseFormReturn } from "react-hook-form";
import { Plus, Trash2 } from "lucide-react";
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
import type { Produit } from "@/lib/produits-api";
import type { RetourFormValues } from "@/lib/retours-form";

type Props = {
  form: UseFormReturn<RetourFormValues>;
  fa: UseFieldArrayReturn<RetourFormValues, "lignes", "id">;
  onProduitChange: (index: number, p: Produit | null) => void;
};

export function LignesSection({ form, fa, onProduitChange }: Props) {
  const { fields, append, remove } = fa;
  const addLigne = () =>
    append({
      produit_id: "",
      reference_produit: "",
      designation: "",
      quantite: 1,
      motif: "",
    });
  return (
    <section className="rounded-md border bg-card p-5 space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">3. Produits retournés</h2>
        <Button type="button" variant="outline" size="sm" onClick={addLigne}>
          <Plus className="h-4 w-4 mr-2" />
          Ajouter une ligne
        </Button>
      </div>

      {fields.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-6">
          Aucun produit. Cliquez sur « Ajouter une ligne ».
        </p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-[35%]">Produit</TableHead>
              <TableHead>Référence</TableHead>
              <TableHead className="text-right w-28">Quantité</TableHead>
              <TableHead className="w-[30%]">Motif</TableHead>
              <TableHead className="w-12" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {fields.map((f, i) => {
              const err = form.formState.errors.lignes?.[i];
              return (
                <TableRow key={f.id}>
                  <TableCell>
                    <ProductSearchSelect
                      value={form.watch(`lignes.${i}.produit_id`)}
                      onChange={(_id, produit) => onProduitChange(i, produit)}
                    />
                    {err?.produit_id && (
                      <p className="text-xs text-red-600 mt-1">{err.produit_id.message}</p>
                    )}
                  </TableCell>
                  <TableCell className="font-mono text-xs">
                    {form.watch(`lignes.${i}.reference_produit`) || "—"}
                  </TableCell>
                  <TableCell className="text-right">
                    <Input
                      type="number"
                      min={1}
                      {...form.register(`lignes.${i}.quantite`, { valueAsNumber: true })}
                      className="text-right"
                    />
                    {err?.quantite && (
                      <p className="text-xs text-red-600 mt-1">{err.quantite.message}</p>
                    )}
                  </TableCell>
                  <TableCell>
                    <Input placeholder="Optionnel" {...form.register(`lignes.${i}.motif`)} />
                  </TableCell>
                  <TableCell>
                    <Button type="button" variant="ghost" size="icon" onClick={() => remove(i)}>
                      <Trash2 className="h-4 w-4 text-red-600" />
                    </Button>
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      )}
      {form.formState.errors.lignes && !Array.isArray(form.formState.errors.lignes) && (
        <p className="text-xs text-red-600">{form.formState.errors.lignes.message as string}</p>
      )}
    </section>
  );
}
