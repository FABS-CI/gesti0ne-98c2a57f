import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { ResponsiveDialog } from "@/components/ui/responsive-dialog";
import type { Commande } from "@/lib/commandes-api";
import type { ColisageInput } from "@/lib/cycle-vente";

interface EmissionBLDialogProps {
  commande: Commande | null;
  onClose: () => void;
  onSubmit: (params: ColisageInput) => void;
  isPending: boolean;
}

const defaultColisage = (): ColisageInput => ({
  nb_colis: 1,
  poids_total: undefined,
  dimensions: "",
  transporteur: "",
  adresse_livraison: "",
  signataire: "",
  decrementer_stock: true,
});

export function EmissionBLDialog({ commande, onClose, onSubmit, isPending }: EmissionBLDialogProps) {
  const [form, setForm] = useState<ColisageInput>(defaultColisage());

  return (
    <ResponsiveDialog
      open={!!commande}
      onOpenChange={(o) => !o && onClose()}
      title={`Émettre BL — ${commande?.reference ?? ""}`}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Annuler
          </Button>
          <Button
            disabled={isPending}
            onClick={() => commande && onSubmit(form)}
            style={{ background: "#F97316" }}
          >
            Émettre BL
          </Button>
        </>
      }
    >
      <div className="grid gap-3">
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label>Nombre de colis *</Label>
            <Input
                type="number"
                min={1}
                value={form.nb_colis}
                onChange={(e) =>
                  setForm({ ...form, nb_colis: Math.max(1, Number(e.target.value) || 1) })
                }
              />
            </div>
            <div>
              <Label>Poids total (kg)</Label>
              <Input
                type="number"
                step="0.01"
                value={form.poids_total ?? ""}
                onChange={(e) =>
                  setForm({
                    ...form,
                    poids_total: e.target.value === "" ? undefined : Number(e.target.value),
                  })
                }
              />
            </div>
          </div>
          <div>
            <Label>Dimensions (LxlxH cm)</Label>
            <Input
              value={form.dimensions ?? ""}
              onChange={(e) => setForm({ ...form, dimensions: e.target.value })}
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label>Transporteur</Label>
              <Input
                value={form.transporteur ?? ""}
                onChange={(e) => setForm({ ...form, transporteur: e.target.value })}
              />
            </div>
            <div>
              <Label>Signataire</Label>
              <Input
                value={form.signataire ?? ""}
                onChange={(e) => setForm({ ...form, signataire: e.target.value })}
              />
            </div>
          </div>
          <div>
            <Label>Adresse de livraison</Label>
            <Textarea
              value={form.adresse_livraison ?? ""}
              onChange={(e) => setForm({ ...form, adresse_livraison: e.target.value })}
            />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.decrementer_stock ?? true}
              onChange={(e) => setForm({ ...form, decrementer_stock: e.target.checked })}
            />
            Décrémenter le stock (sortie)
          </label>
      </div>
    </ResponsiveDialog>
  );
}
