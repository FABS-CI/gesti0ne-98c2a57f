import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import {
  CATEGORIES_TRANSACTION,
  MODES_PAIEMENT,
  STATUTS_TRANSACTION,
  TYPES_TRANSACTION,
  type TransactionInput,
} from "@/lib/finances-api";

type Props = {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  editing: boolean;
  form: TransactionInput;
  setForm: React.Dispatch<React.SetStateAction<TransactionInput>>;
  onSubmit: () => void;
  submitting: boolean;
};

export function TransactionFormDialog({
  open,
  onOpenChange,
  editing,
  form,
  setForm,
  onSubmit,
  submitting,
}: Props) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>{editing ? "Modifier la transaction" : "Nouvelle transaction"}</DialogTitle>
        </DialogHeader>
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <Label>Type</Label>
            <Select value={form.type} onValueChange={(v) => setForm((f) => ({ ...f, type: v }))}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {TYPES_TRANSACTION.map((t) => (
                  <SelectItem key={t.value} value={t.value}>
                    {t.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5">
            <Label>Catégorie</Label>
            <Select
              value={form.categorie}
              onValueChange={(v) => setForm((f) => ({ ...f, categorie: v }))}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {CATEGORIES_TRANSACTION.map((c) => (
                  <SelectItem key={c.value} value={c.value}>
                    {c.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5 sm:col-span-2">
            <Label>Libellé</Label>
            <Input
              value={form.libelle}
              onChange={(e) => setForm((f) => ({ ...f, libelle: e.target.value }))}
              placeholder="Description de la transaction"
            />
          </div>
          <div className="space-y-1.5">
            <Label>Montant (FCFA)</Label>
            <Input
              type="number"
              min={0}
              value={form.montant}
              onChange={(e) => setForm((f) => ({ ...f, montant: Number(e.target.value) }))}
            />
          </div>
          <div className="space-y-1.5">
            <Label>Date</Label>
            <Input
              type="date"
              value={form.date_transaction}
              onChange={(e) => setForm((f) => ({ ...f, date_transaction: e.target.value }))}
            />
          </div>
          <div className="space-y-1.5">
            <Label>Mode de paiement</Label>
            <Select
              value={form.mode_paiement}
              onValueChange={(v) => setForm((f) => ({ ...f, mode_paiement: v }))}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {MODES_PAIEMENT.map((m) => (
                  <SelectItem key={m.value} value={m.value}>
                    {m.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5">
            <Label>Statut</Label>
            <Select
              value={form.statut}
              onValueChange={(v) => setForm((f) => ({ ...f, statut: v }))}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {STATUTS_TRANSACTION.map((s) => (
                  <SelectItem key={s.value} value={s.value}>
                    {s.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5 sm:col-span-2">
            <Label>Notes</Label>
            <Textarea
              value={form.notes ?? ""}
              onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))}
              rows={2}
            />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Annuler
          </Button>
          <Button onClick={onSubmit} disabled={submitting}>
            {editing ? "Enregistrer" : "Créer"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
