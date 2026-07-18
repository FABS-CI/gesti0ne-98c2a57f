import type { UseFormReturn } from "react-hook-form";
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
import type { Depot } from "@/lib/depots-api";
import type { RetourFormValues } from "@/lib/retours-form";

type Props = {
  form: UseFormReturn<RetourFormValues>;
  depots: Depot[];
};

export function InfosSection({ form, depots }: Props) {
  const typeRetour = form.watch("type_retour");
  return (
    <section className="rounded-md border bg-card p-5 space-y-4">
      <h2 className="text-lg font-semibold">2. Informations du retour</h2>
      <div className="grid gap-4 md:grid-cols-2">
        <div>
          <Label>Numéro</Label>
          <Input value="(généré automatiquement)" readOnly disabled />
        </div>
        <div>
          <Label htmlFor="date_retour">Date *</Label>
          <Input id="date_retour" type="date" {...form.register("date_retour")} />
        </div>
        <div className="md:col-span-2">
          <Label>Type de retour *</Label>
          <Select
            value={typeRetour ?? "physique"}
            onValueChange={(v) =>
              form.setValue("type_retour", v as "physique" | "avoir", { shouldValidate: true })
            }
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="physique">
                Retour physique — marchandise réintégrée au stock
              </SelectItem>
              <SelectItem value="avoir">
                Avoir financier — crédit client sans retour de produits
              </SelectItem>
            </SelectContent>
          </Select>
          <p className="mt-1 text-xs text-muted-foreground">
            {typeRetour === "avoir"
              ? "Le stock ne sera pas impacté. Seul le compte client (ou la facture liée) est crédité."
              : "Les quantités seront réintégrées au dépôt sélectionné, avec traçabilité (référence, date, utilisateur)."}
          </p>
        </div>
        {typeRetour !== "avoir" && (
          <div>
            <Label>Dépôt de réintégration *</Label>
            <Select
              value={form.watch("depot_id") ?? ""}
              onValueChange={(v) => form.setValue("depot_id", v, { shouldValidate: true })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Choisir un dépôt" />
              </SelectTrigger>
              <SelectContent>
                {depots
                  .filter((d) => d.actif)
                  .map((d) => (
                    <SelectItem key={d.depot_id} value={d.depot_id}>
                      {d.nom}
                      {d.is_principal ? " — Principal" : ""}
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>
        )}
        <div className="md:col-span-2">
          <Label htmlFor="observations">Observations</Label>
          <Textarea id="observations" rows={2} {...form.register("observations")} />
        </div>
      </div>
    </section>
  );
}
